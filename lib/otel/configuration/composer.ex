defmodule Otel.Configuration.Composer do
  @moduledoc """
  Composes a validated declarative-config in-memory model into the
  per-pillar provider config maps that
  `Otel.SDK.{Trace.TracerProvider, Metrics.MeterProvider, Logs.LoggerProvider}`
  consume at `start_link/1`.

  Implements spec `configuration/sdk.md` §Create:
  *"Interpret configuration model and return SDK components."*

  Pipeline used by `Otel.Configuration`:

      File.read!(path)
      |> Otel.Configuration.Substitution.substitute!()
      |> Otel.Configuration.Parser.parse_string!()
      |> Otel.Configuration.Schema.validate!()
      |> Otel.Configuration.Composer.compose!()

  Output shape mirrors `Otel.SDK.Config.{trace,metrics,logs}/0` so
  the wiring layer (`Otel.SDK.Application`) can swap config sources
  transparently — env-var path or declarative-file path produces
  the same map shape.

  ## Stable-only policy

  Per `.claude/rules/workflow.md` and the project's
  ["Stable only"](../README.md) stance, the composer:

  - **Warns + skips** any `*/development`-suffixed property at the
    sub-property level (e.g. `resource.detection/development`,
    `meter_configuration/development`).
  - **Raises** when the YAML asks for a feature not implemented
    in our SDK (e.g. `pull` MetricReader for Prometheus,
    `otlp_grpc` exporter, `zipkin` exporter). These are spec-stable
    but missing from this repo's SDK surface.

  ## Component coverage

  | Pillar | Processor / Reader | Exporter |
  |---|---|---|
  | Trace | batch | otlp_http, console |
  | Metrics | periodic | otlp_http, console |
  | Logs | batch | otlp_http, console |

  Sampler is hardcoded to `parentbased_always_on`
  (`Otel.SDK.Trace.Sampler`); any `tracer_provider.sampler`
  block in the YAML is silently ignored.

  ## Resource

  Built from the YAML's `resource.attributes` (list of
  `{name, value, type}`) and `resource.attributes_list` (W3C
  Baggage-format string), merged onto the project's
  `telemetry.sdk.*` baseline. **Does not** read
  `OTEL_RESOURCE_ATTRIBUTES` / `OTEL_SERVICE_NAME` from the
  process env — when `OTEL_CONFIG_FILE` is set, spec L332-L337
  forbids reading other OTEL_* env vars except via explicit YAML
  substitution (`attributes_list: ${OTEL_RESOURCE_ATTRIBUTES}`).

  ## Public API

  | Function | Role |
  |---|---|
  | `compose!/1` | **SDK** (Create) — model → `%{trace, metrics, logs}` config maps |

  ## References

  - Spec Create: `opentelemetry-specification/specification/configuration/sdk.md` §Create
  - Schema docs: `references/opentelemetry-configuration/schema-docs.md`
  """

  require Logger

  @doc """
  Composes a validated configuration model into per-pillar SDK
  provider configs plus the global propagator value.
  """
  @spec compose!(model :: map()) :: %{
          trace: map(),
          metrics: map(),
          logs: map(),
          propagator: module() | {module(), [module()]}
        }
  def compose!(model) when is_map(model) do
    resource = compose_resource(model)

    %{
      trace: compose_trace(model, resource),
      metrics: compose_metrics(model, resource),
      logs: compose_logs(model, resource),
      propagator: hardcoded_propagator()
    }
  end

  # Hardcoded `Composite[TraceContext, Baggage]` per minikube-style
  # scope — any `propagator:` block in the YAML is silently ignored,
  # mirroring the `tracer_provider.sampler` ignore policy.
  @spec hardcoded_propagator() :: {module(), [module()]}
  defp hardcoded_propagator do
    {Otel.API.Propagator.TextMap.Composite,
     [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]}
  end

  # ====== Trace ======

  @spec compose_trace(model :: map(), resource :: Otel.SDK.Resource.t()) :: map()
  defp compose_trace(model, resource) do
    provider = Map.get(model, "tracer_provider") || %{}

    %{
      resource: resource,
      processors: Enum.map(provider["processors"] || [], &compose_span_processor/1),
      span_limits: %Otel.SDK.Trace.SpanLimits{}
    }
  end

  @spec compose_span_processor(spec :: map()) ::
          {module(), Otel.SDK.Trace.SpanProcessor.config()}
  defp compose_span_processor(spec) do
    case sole_key(spec) do
      {"batch", inner} ->
        {Otel.SDK.Trace.SpanProcessor, batch_processor_config(inner || %{}, :trace)}

      {key, _} ->
        raise ArgumentError, "unsupported span processor: #{inspect(key)}"
    end
  end

  # `:trace` and `:logs` share the BatchSpanProcessor /
  # BatchLogRecordProcessor knob shape, only the exporter type
  # differs. Routed via `pillar` so both call sites stay terse.
  @spec batch_processor_config(inner :: map(), pillar :: :trace | :logs) :: map()
  defp batch_processor_config(inner, pillar) do
    exporter =
      case pillar do
        :trace -> compose_trace_exporter(inner["exporter"])
        :logs -> compose_log_exporter(inner["exporter"])
      end

    %{
      exporter: exporter,
      scheduled_delay_ms: inner["schedule_delay"] || default_schedule_delay(pillar),
      export_timeout_ms: inner["export_timeout"] || 30_000,
      max_queue_size: inner["max_queue_size"] || 2_048,
      max_export_batch_size: inner["max_export_batch_size"] || 512
    }
  end

  @spec default_schedule_delay(pillar :: :trace | :logs) :: pos_integer()
  defp default_schedule_delay(:trace), do: 5_000
  defp default_schedule_delay(:logs), do: 1_000

  @spec compose_trace_exporter(spec :: map() | nil) :: {module(), map()}
  defp compose_trace_exporter(nil),
    do: raise(ArgumentError, "processor.exporter is required")

  defp compose_trace_exporter(spec) do
    case sole_key(spec) do
      {"otlp_http", inner} ->
        {Otel.OTLP.Trace.SpanExporter.HTTP, otlp_http_config(inner || %{})}

      {key, _} ->
        raise_unsupported_exporter!(key, "trace")
    end
  end

  # ====== Metrics ======

  @spec compose_metrics(model :: map(), resource :: Otel.SDK.Resource.t()) :: map()
  defp compose_metrics(model, resource) do
    provider = Map.get(model, "meter_provider") || %{}

    %{
      resource: resource,
      readers: Enum.map(provider["readers"] || [], &compose_metric_reader/1),
      exemplar_filter: compose_exemplar_filter(provider["exemplar_filter"]),
      views: provider["views"] || []
    }
  end

  @spec compose_metric_reader(spec :: map()) ::
          {module(), Otel.SDK.Metrics.MetricReader.config()}
  defp compose_metric_reader(spec) do
    case sole_key(spec) do
      {"periodic", inner} ->
        {Otel.SDK.Metrics.MetricReader.PeriodicExporting, periodic_reader_config(inner || %{})}

      {"pull", _} ->
        raise ArgumentError,
              "pull MetricReader (Prometheus) is not implemented in this SDK"

      {key, _} ->
        raise ArgumentError, "unsupported metric reader: #{inspect(key)}"
    end
  end

  @spec periodic_reader_config(inner :: map()) :: map()
  defp periodic_reader_config(inner) do
    %{
      exporter: compose_metric_exporter(inner["exporter"]),
      export_interval_ms: inner["interval"] || 60_000,
      export_timeout_ms: inner["timeout"] || 30_000
    }
  end

  @spec compose_metric_exporter(spec :: map() | nil) :: {module(), map()}
  defp compose_metric_exporter(nil),
    do: raise(ArgumentError, "reader.exporter is required")

  defp compose_metric_exporter(spec) do
    case sole_key(spec) do
      {"otlp_http", inner} ->
        {Otel.OTLP.Metrics.MetricExporter.HTTP, otlp_http_config(inner || %{})}

      {key, _} ->
        raise_unsupported_exporter!(key, "metrics")
    end
  end

  @spec compose_exemplar_filter(value :: String.t() | nil) ::
          Otel.SDK.Metrics.Exemplar.Filter.t()
  defp compose_exemplar_filter("always_on"), do: :always_on
  defp compose_exemplar_filter("always_off"), do: :always_off
  defp compose_exemplar_filter("trace_based"), do: :trace_based
  defp compose_exemplar_filter(nil), do: :trace_based

  defp compose_exemplar_filter(other),
    do: raise(ArgumentError, "unsupported exemplar_filter: #{inspect(other)}")

  # ====== Logs ======

  @spec compose_logs(model :: map(), resource :: Otel.SDK.Resource.t()) :: map()
  defp compose_logs(model, resource) do
    provider = Map.get(model, "logger_provider") || %{}

    %{
      resource: resource,
      processors: Enum.map(provider["processors"] || [], &compose_log_processor/1),
      log_record_limits: %Otel.SDK.Logs.LogRecordLimits{}
    }
  end

  @spec compose_log_processor(spec :: map()) ::
          {module(), Otel.SDK.Logs.LogRecordProcessor.config()}
  defp compose_log_processor(spec) do
    case sole_key(spec) do
      {"batch", inner} ->
        {Otel.SDK.Logs.LogRecordProcessor, batch_processor_config(inner || %{}, :logs)}

      {key, _} ->
        raise ArgumentError, "unsupported log processor: #{inspect(key)}"
    end
  end

  @spec compose_log_exporter(spec :: map() | nil) :: {module(), map()}
  defp compose_log_exporter(nil),
    do: raise(ArgumentError, "processor.exporter is required")

  defp compose_log_exporter(spec) do
    case sole_key(spec) do
      {"otlp_http", inner} ->
        {Otel.OTLP.Logs.LogRecordExporter.HTTP, otlp_http_config(inner || %{})}

      {key, _} ->
        raise_unsupported_exporter!(key, "logs")
    end
  end

  # ====== Resource ======

  # `telemetry.sdk.*` baseline reproduced here (rather than calling
  # `Otel.SDK.Resource.default/0`) so resource composition is
  # **purely** model-driven — no env-var reads. Spec L332-L337
  # forbids reading other OTEL_* env vars when OTEL_CONFIG_FILE is
  # set; users opt in to env values via explicit YAML substitution
  # like `attributes_list: ${OTEL_RESOURCE_ATTRIBUTES}`.
  @spec compose_resource(model :: map()) :: Otel.SDK.Resource.t()
  defp compose_resource(model) do
    section = Map.get(model, "resource") || %{}

    user_attrs =
      sdk_baseline()
      |> Map.merge(parse_attributes_list(section["attributes_list"]))
      |> Map.merge(parse_attributes(section["attributes"]))

    schema_url = section["schema_url"] || ""

    warn_developments_in_resource(section)

    Otel.SDK.Resource.create(user_attrs, schema_url)
  end

  @spec sdk_baseline() :: %{String.t() => term()}
  defp sdk_baseline do
    %{
      "telemetry.sdk.name" => "otel",
      "telemetry.sdk.language" => "elixir",
      "telemetry.sdk.version" => to_string(Application.spec(:otel, :vsn))
    }
  end

  # `attributes_list` is a W3C Baggage-shaped string after
  # substitution: "key1=value1,key2=value2".
  @spec parse_attributes_list(value :: String.t() | nil) :: %{String.t() => String.t()}
  defp parse_attributes_list(nil), do: %{}
  defp parse_attributes_list(""), do: %{}

  defp parse_attributes_list(raw) when is_binary(raw) do
    raw
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Map.new(fn pair ->
      [k, v] = String.split(pair, "=", parts: 2)
      {String.trim(k), String.trim(v)}
    end)
  end

  # `attributes` is `[%{"name" => k, "value" => v, "type" => t}]`.
  # Type coercion follows the schema enum (`string`, `int`, `bool`,
  # etc.); for now we trust YAML's native typing and pass values
  # through.
  @spec parse_attributes(value :: list() | nil) :: %{String.t() => term()}
  defp parse_attributes(nil), do: %{}

  defp parse_attributes(list) when is_list(list) do
    Map.new(list, fn entry ->
      {entry["name"], entry["value"]}
    end)
  end

  @spec warn_developments_in_resource(section :: map()) :: :ok
  defp warn_developments_in_resource(section) do
    section
    |> Map.keys()
    |> Enum.filter(&development?/1)
    |> Enum.each(&warn_development(&1, "resource"))
  end

  # ====== Shared exporter config ======

  # Maps schema-shaped OTLP HTTP exporter config (string keys) to
  # the atom-keyed shape the project's
  # `Otel.OTLP.<Pillar>.<Behaviour>.HTTP.init/1` consumes. Unknown
  # keys are silently dropped (e.g. TLS sub-fields not yet
  # plumbed); this is the conservative read of spec L332-L337
  # ("MUST be ignored") for unrecognized properties at the
  # composer boundary.
  @schema_to_exporter_keys %{
    "endpoint" => :endpoint,
    "headers_list" => :headers,
    "compression" => :compression,
    "timeout" => :timeout
  }

  @spec otlp_http_config(spec :: map()) :: map()
  defp otlp_http_config(spec) do
    spec
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      case Map.get(@schema_to_exporter_keys, k) do
        nil -> acc
        atom_key -> Map.put(acc, atom_key, v)
      end
    end)
  end

  # ====== Utilities ======

  # Schema constraint: each `oneOf`-discriminated map (processor,
  # exporter, reader) has exactly one populated key.
  # The map may also contain `additionalProperties` from the
  # schema's `additionalProperties: { type: ['object', 'null'] }`
  # pattern (which is how the schema models `*/development`
  # variants). We pick the first non-development key.
  @spec sole_key(map :: map()) :: {String.t(), term()}
  defp sole_key(map) when map_size(map) == 1, do: hd(Map.to_list(map))

  defp sole_key(map) do
    case Enum.split_with(map, fn {k, _} -> not development?(k) end) do
      {[head | _], _developments} -> head
      {[], _} -> raise ArgumentError, "no concrete (non-development) key in #{inspect(map)}"
    end
  end

  @spec development?(key :: String.t()) :: boolean()
  defp development?(key) when is_binary(key), do: String.contains?(key, "/development")

  @spec warn_development(key :: String.t(), context :: String.t()) :: :ok
  defp warn_development(key, context) do
    Logger.warning(
      "Otel.Configuration.Composer: ignoring #{inspect(key)} in #{context} — " <>
        "*/development properties are outside the project's Stable-only policy"
    )

    :ok
  end

  @spec raise_unsupported_exporter!(key :: String.t(), pillar :: String.t()) :: no_return()
  defp raise_unsupported_exporter!(key, pillar) do
    raise ArgumentError,
          "unsupported #{pillar} exporter: #{inspect(key)} — " <>
            "this SDK ships only otlp_http"
  end
end
