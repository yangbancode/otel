defmodule Otel.SDK.Config do
  @moduledoc """
  Composes provider configuration from three layers, in precedence
  order from highest to lowest:

  1. **Programmatic** — anything the caller passes directly to a
     provider's `start_link(config: ...)` overrides every layer
     below. (Outside this module's scope: providers receive the
     map this module produces and merge it with the caller's
     `start_link` config.)
  2. **OS env (`OTEL_*`)** — spec
     `configuration/sdk-environment-variables.md` L48-L50:
     *"Implementations MAY choose to allow configuration via the
     environment variables ... they SHOULD use the names and
     value parsing behavior specified in this document."*
  3. **Application env** — `Application.get_env(:otel, pillar,
     [])`. Lets users configure the SDK declaratively from
     `config/runtime.exs` or `config/<env>.exs`.
  4. **Built-in defaults** — defined inline below. Several
     components are *hardcoded* and not configurable:
     Sampler (`parentbased_always_on`), IdGenerator (random),
     SpanProcessor / LogRecordProcessor (batch), and **exporter
     (OTLP/HTTP)**. To stop emitting telemetry, set
     `config :otel, disabled: true`.

  ## Configuration UX

  ```elixir
  # config/runtime.exs
  config :otel,
    trace: [
      resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"}),
      span_limits: %{attribute_count_limit: 256}
    ],
    metrics: [
      resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"}),
      reader_config: %{export_interval_ms: 30_000}
    ],
    logs: [
      resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"})
    ]
  ```

  ## Public API

  | Function | Returns |
  |---|---|
  | `disabled?/0` | `OTEL_SDK_DISABLED == true`; `Application.start/2` skips registering providers when true |
  | `trace/0` | TracerProvider config map |
  | `metrics/0` | MeterProvider config map |
  | `logs/0` | LoggerProvider config map |
  | `propagator/0` | Global TextMap propagator (single module or `{Composite, [...]}`) |

  ## Out of scope (future PRs)

  - **`OTEL_CONFIG_FILE`** (declarative YAML) — when set, spec L332
    *"all other env vars... MUST be ignored"*. A whole-config
    short-circuit; handled by `Otel.Configuration` —
    `Otel.SDK.Application` detects the env var and routes through
    `Otel.Configuration.load!/0`.
  - **OTLP exporter knobs** (`OTEL_EXPORTER_OTLP_*`) — already read
    by each `Otel.OTLP.<Pillar>.Exporter.HTTP` module on its own.
    The SDK config layer only selects *which* exporter; the chosen
    exporter parses its own env vars at `init/1`.

  ## References

  - OTel SDK env vars: `opentelemetry-specification/specification/configuration/sdk-environment-variables.md`
  - OTel Trace SDK: `opentelemetry-specification/specification/trace/sdk.md`
  - OTel Metrics SDK: `opentelemetry-specification/specification/metrics/sdk.md`
  - OTel Logs SDK: `opentelemetry-specification/specification/logs/sdk.md`
  """

  require Logger

  # ====== General ======

  @doc """
  Returns `true` when `OTEL_SDK_DISABLED=true` (case-insensitive).

  Spec L113-L114 — *"Disable the SDK for all signals... If `true`,
  a no-op SDK implementation will be used for all telemetry signals.
  Any propagators set via the `OTEL_PROPAGATORS` environment variable
  will be non-no-op."*
  """
  @spec disabled?() :: boolean()
  def disabled? do
    Otel.SDK.Config.Env.boolean("OTEL_SDK_DISABLED") == true
  end

  # ====== Trace ======

  @doc """
  Builds the TracerProvider config map by composing defaults,
  Application env, and `OTEL_*` env vars.
  """
  @spec trace() :: map()
  def trace do
    pillar = Application.get_env(:otel, :trace, [])

    %{
      resource: Keyword.get(pillar, :resource, Otel.SDK.Resource.default()),
      processors: build_trace_processors(pillar),
      span_limits: build_span_limits(pillar)
    }
  end

  @spec build_trace_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
  defp build_trace_processors(pillar) do
    case Keyword.get(pillar, :processors) do
      nil -> default_trace_processors(pillar)
      processors -> processors
    end
  end

  @spec default_trace_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
  defp default_trace_processors(_pillar) do
    [{Otel.SDK.Trace.SpanProcessor, %{exporter: {Otel.OTLP.Trace.SpanExporter.HTTP, %{}}}}]
  end

  @spec build_span_limits(pillar :: keyword()) :: Otel.SDK.Trace.SpanLimits.t()
  defp build_span_limits(pillar) do
    overrides =
      pillar
      |> Keyword.get(:span_limits, %{})
      |> normalize_struct_or_keyword()

    env_limits = %{
      attribute_count_limit:
        Otel.SDK.Config.Env.integer("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT") ||
          Otel.SDK.Config.Env.integer("OTEL_ATTRIBUTE_COUNT_LIMIT") || 128,
      attribute_value_length_limit:
        Otel.SDK.Config.Env.integer("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT") ||
          Otel.SDK.Config.Env.integer("OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT") || :infinity,
      event_count_limit: Otel.SDK.Config.Env.integer("OTEL_SPAN_EVENT_COUNT_LIMIT") || 128,
      link_count_limit: Otel.SDK.Config.Env.integer("OTEL_SPAN_LINK_COUNT_LIMIT") || 128,
      attribute_per_event_limit:
        Otel.SDK.Config.Env.integer("OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT") || 128,
      attribute_per_link_limit:
        Otel.SDK.Config.Env.integer("OTEL_LINK_ATTRIBUTE_COUNT_LIMIT") || 128
    }

    struct(Otel.SDK.Trace.SpanLimits, Map.merge(env_limits, overrides))
  end

  # ====== Metrics ======

  @doc """
  Builds the MeterProvider config map.
  """
  @spec metrics() :: map()
  def metrics do
    pillar = Application.get_env(:otel, :metrics, [])

    %{
      resource: Keyword.get(pillar, :resource, Otel.SDK.Resource.default()),
      readers: build_metrics_readers(pillar),
      exemplar_filter: build_exemplar_filter(pillar),
      views: Keyword.get(pillar, :views, [])
    }
  end

  @spec build_metrics_readers(pillar :: keyword()) ::
          [{module(), Otel.SDK.Metrics.MetricReader.config()}]
  defp build_metrics_readers(pillar) do
    case Keyword.get(pillar, :readers) do
      nil -> default_metrics_readers(pillar)
      readers -> readers
    end
  end

  @spec default_metrics_readers(pillar :: keyword()) ::
          [{module(), Otel.SDK.Metrics.MetricReader.config()}]
  defp default_metrics_readers(pillar) do
    [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, reader_config(pillar)}]
  end

  @spec reader_config(pillar :: keyword()) :: map()
  defp reader_config(pillar) do
    overrides = Keyword.get(pillar, :reader_config, %{})

    base = %{
      exporter: {Otel.OTLP.Metrics.MetricExporter.HTTP, %{}},
      export_interval_ms:
        Otel.SDK.Config.Env.duration_ms("OTEL_METRIC_EXPORT_INTERVAL") || 60_000,
      export_timeout_ms: Otel.SDK.Config.Env.timeout_ms("OTEL_METRIC_EXPORT_TIMEOUT") || 30_000
    }

    Map.merge(base, overrides)
  end

  @spec build_exemplar_filter(pillar :: keyword()) :: Otel.SDK.Metrics.Exemplar.Filter.t()
  defp build_exemplar_filter(pillar) do
    cond do
      explicit = Keyword.get(pillar, :exemplar_filter) ->
        explicit

      from_env =
          Otel.SDK.Config.Env.enum("OTEL_METRICS_EXEMPLAR_FILTER", [
            :always_on,
            :always_off,
            :trace_based
          ]) ->
        from_env

      true ->
        :trace_based
    end
  end

  # ====== Logs ======

  @doc """
  Builds the LoggerProvider config map.
  """
  @spec logs() :: map()
  def logs do
    pillar = Application.get_env(:otel, :logs, [])

    %{
      resource: Keyword.get(pillar, :resource, Otel.SDK.Resource.default()),
      processors: build_logs_processors(pillar),
      log_record_limits: build_log_record_limits(pillar)
    }
  end

  @spec build_logs_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Logs.LogRecordProcessor.config()}]
  defp build_logs_processors(pillar) do
    case Keyword.get(pillar, :processors) do
      nil -> default_logs_processors(pillar)
      processors -> processors
    end
  end

  @spec default_logs_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Logs.LogRecordProcessor.config()}]
  defp default_logs_processors(_pillar) do
    [
      {Otel.SDK.Logs.LogRecordProcessor,
       %{exporter: {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{}}}}
    ]
  end

  @spec build_log_record_limits(pillar :: keyword()) :: Otel.SDK.Logs.LogRecordLimits.t()
  defp build_log_record_limits(pillar) do
    overrides =
      pillar
      |> Keyword.get(:log_record_limits, %{})
      |> normalize_struct_or_keyword()

    env_limits = %{
      attribute_count_limit:
        Otel.SDK.Config.Env.integer("OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT") ||
          Otel.SDK.Config.Env.integer("OTEL_ATTRIBUTE_COUNT_LIMIT") || 128,
      attribute_value_length_limit:
        Otel.SDK.Config.Env.integer("OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT") ||
          Otel.SDK.Config.Env.integer("OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT") || :infinity
    }

    struct(Otel.SDK.Logs.LogRecordLimits, Map.merge(env_limits, overrides))
  end

  # Accept both keyword (`[attribute_count_limit: 128]`) and
  # struct (`%LogRecordLimits{...}`, `%SpanLimits{...}`) forms
  # in pillar overrides. Strips the `:__struct__` key so it
  # does not collide with `struct/2`'s default-application
  # path. Plain maps pass through untouched.
  @spec normalize_struct_or_keyword(value :: keyword() | map() | struct()) :: map()
  defp normalize_struct_or_keyword(value) when is_map(value) do
    Map.delete(value, :__struct__)
  end

  defp normalize_struct_or_keyword(value) when is_list(value) do
    Enum.into(value, %{})
  end

  # ====== Propagator ======

  @doc """
  Builds the global TextMap propagator value to install via
  `Otel.API.Propagator.TextMap.set_propagator/1`.

  Spec L122-L131 (`OTEL_PROPAGATORS`): comma-separated list of
  propagator names, default `"tracecontext,baggage"`. Values
  MUST be deduplicated (L118).

  Returns:
  - the `Otel.API.Propagator.TextMap.Noop` module when the
    list is empty or contains `"none"` (spec L130 — *"No
    automatically configured propagator"*);
  - a single propagator module when the list has one entry;
  - `{Otel.API.Propagator.TextMap.Composite, [...]}` from
    `Composite.new/1` for two or more entries.

  Mix Config (`config :otel, propagators: [...]`) takes
  precedence over `OTEL_PROPAGATORS`. The list may contain
  shortcut atoms (`:tracecontext`, `:baggage`, `:none`) or
  custom propagator modules; see `Otel.SDK.Config.Selector.propagator/1`
  for the full mapping.
  """
  @spec propagator() :: module() | {module(), [module()]}
  def propagator do
    selectors =
      :otel
      |> Application.get_env(:propagators)
      |> case do
        nil -> propagators_from_env() || [:tracecontext, :baggage]
        list when is_list(list) -> list
      end
      |> Enum.uniq()

    cond do
      :none in selectors ->
        Otel.API.Propagator.TextMap.Noop

      selectors == [] ->
        Otel.API.Propagator.TextMap.Noop

      length(selectors) == 1 ->
        Otel.SDK.Config.Selector.propagator(hd(selectors))

      true ->
        selectors
        |> Enum.map(&Otel.SDK.Config.Selector.propagator/1)
        |> Otel.API.Propagator.TextMap.Composite.new()
    end
  end

  # Spec L116 default `"tracecontext,baggage"` is applied at the
  # call site (when both env-var and Mix Config are absent), so
  # this helper returns `nil` rather than the default itself —
  # makes the call-site `||` chain readable.
  @spec propagators_from_env() :: [atom()] | nil
  defp propagators_from_env do
    case Otel.SDK.Config.Env.list("OTEL_PROPAGATORS") do
      nil -> nil
      [] -> nil
      raw -> raw |> Enum.map(&parse_propagator_name/1) |> Enum.reject(&is_nil/1)
    end
  end

  # Spec L122-L131 enumerates 8 known propagator names. Limiting
  # `String.to_atom/1` to those names keeps adversarial env-var
  # input from polluting the atom table. Unknown names trigger
  # spec L107's MUST: warn + ignore.
  @known_propagator_names ~w(tracecontext baggage b3 b3multi jaeger xray ottrace none)

  @spec parse_propagator_name(name :: String.t()) :: atom() | nil
  defp parse_propagator_name(name) when name in @known_propagator_names do
    String.to_atom(name)
  end

  defp parse_propagator_name(unknown) do
    Logger.warning(
      "Otel.SDK.Config: OTEL_PROPAGATORS contains unknown name #{inspect(unknown)}; " <>
        "ignoring (spec L107 — unrecognized values MUST warn + be ignored)"
    )

    nil
  end
end
