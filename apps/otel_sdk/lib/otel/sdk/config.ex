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
  3. **Application env** — `Application.get_env(:otel_sdk, pillar,
     [])`. Lets users configure the SDK declaratively from
     `config/runtime.exs` or `config/<env>.exs`.
  4. **Built-in defaults** — defined inline below; mirror the spec
     defaults (sampler `parentbased_always_on`, exporter `otlp`,
     processor `batch`, etc.).

  ## Configuration UX

  ```elixir
  # config/runtime.exs
  config :otel_sdk,
    trace: [
      sampler: :parentbased_always_on,
      exporter: :otlp,                       # short form, blessed names
      processor: :batch,
      span_limits: %{attribute_count_limit: 256}
    ],
    metrics: [
      exporter: :otlp,
      export_interval_ms: 30_000
    ],
    logs: [
      exporter: {MyApp.CustomExporter, %{api_key: System.get_env("X")}},
      processor: :batch
    ]
  ```

  All exporter / processor / sampler values accept the three forms
  documented in `Otel.SDK.Config.Selector`.

  ## Public API

  | Function | Returns |
  |---|---|
  | `disabled?/0` | `OTEL_SDK_DISABLED == true`; `Application.start/2` skips registering providers when true |
  | `trace/0` | TracerProvider config map |
  | `metrics/0` | MeterProvider config map |
  | `logs/0` | LoggerProvider config map |

  ## Out of scope (future PRs)

  - **`OTEL_CONFIG_FILE`** (declarative YAML) — when set, spec L332
    *"all other env vars... MUST be ignored"*. A whole-config
    short-circuit; deserves its own implementation pass.
  - **`OTEL_PROPAGATORS`** — needs composite-propagator wiring; can
    land in a follow-up that touches `Otel.API.Propagator`.
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
    pillar = Application.get_env(:otel_sdk, :trace, [])

    %{
      resource: Otel.SDK.Resource.default(),
      sampler: build_sampler(pillar),
      processors: build_trace_processors(pillar),
      span_limits: build_span_limits(pillar),
      id_generator: Keyword.get(pillar, :id_generator, Otel.SDK.Trace.IdGenerator.Default)
    }
  end

  @spec build_sampler(pillar :: keyword()) :: {module(), term()}
  defp build_sampler(pillar) do
    cond do
      explicit = Keyword.get(pillar, :sampler) ->
        Otel.SDK.Config.Selector.sampler(explicit)

      from_env = sampler_from_env() ->
        Otel.SDK.Config.Selector.sampler(from_env)

      true ->
        Otel.SDK.Config.Selector.sampler(:parentbased_always_on)
    end
  end

  # `OTEL_TRACES_SAMPLER` enum + `OTEL_TRACES_SAMPLER_ARG` paired
  # parsing per spec L143-L152. Returns the selector input expected
  # by `Selector.sampler/1` (atom or `{atom, ratio}` tuple).
  @spec sampler_from_env() :: atom() | {atom(), float()} | nil
  defp sampler_from_env do
    case Otel.SDK.Config.Env.enum("OTEL_TRACES_SAMPLER", [
           :always_on,
           :always_off,
           :traceidratio,
           :parentbased_always_on,
           :parentbased_always_off,
           :parentbased_traceidratio
         ]) do
      nil ->
        nil

      sampler when sampler in [:traceidratio, :parentbased_traceidratio] ->
        {sampler, sampler_ratio_arg()}

      sampler ->
        sampler
    end
  end

  # Spec L147 — for `traceidratio` / `parentbased_traceidratio`,
  # `OTEL_TRACES_SAMPLER_ARG` is a float in [0..1] with default 1.0.
  @spec sampler_ratio_arg() :: float()
  defp sampler_ratio_arg do
    case Otel.SDK.Config.Env.string("OTEL_TRACES_SAMPLER_ARG") do
      nil -> 1.0
      raw -> parse_ratio(raw)
    end
  end

  @spec parse_ratio(raw :: String.t()) :: float()
  defp parse_ratio(raw) do
    case Float.parse(raw) do
      {n, ""} when n >= 0.0 and n <= 1.0 -> n
      _ -> 1.0
    end
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
  defp default_trace_processors(pillar) do
    case trace_exporter(pillar) do
      :none -> []
      exporter -> [{trace_processor_module(pillar), trace_processor_config(pillar, exporter)}]
    end
  end

  @spec trace_exporter(pillar :: keyword()) :: {module(), map()} | :none
  defp trace_exporter(pillar) do
    cond do
      explicit = Keyword.get(pillar, :exporter) ->
        Otel.SDK.Config.Selector.trace_exporter(explicit)

      from_env =
          Otel.SDK.Config.Env.enum("OTEL_TRACES_EXPORTER", [:otlp, :console, :none]) ->
        Otel.SDK.Config.Selector.trace_exporter(from_env)

      true ->
        Otel.SDK.Config.Selector.trace_exporter(:otlp)
    end
  end

  @spec trace_processor_module(pillar :: keyword()) :: module()
  defp trace_processor_module(pillar) do
    pillar
    |> Keyword.get(:processor, :batch)
    |> Otel.SDK.Config.Selector.trace_processor()
  end

  # Forwards the OTEL_BSP_* knobs into the Batch processor's init
  # config. Simple processor ignores the BSP knobs harmlessly.
  @spec trace_processor_config(pillar :: keyword(), exporter :: {module(), map()}) :: map()
  defp trace_processor_config(pillar, exporter) do
    overrides = Keyword.get(pillar, :processor_config, %{})

    base = %{
      exporter: exporter,
      scheduled_delay_ms:
        Otel.SDK.Config.Env.duration_ms("OTEL_BSP_SCHEDULE_DELAY") || 5_000,
      export_timeout_ms:
        Otel.SDK.Config.Env.timeout_ms("OTEL_BSP_EXPORT_TIMEOUT") || 30_000,
      max_queue_size: Otel.SDK.Config.Env.integer("OTEL_BSP_MAX_QUEUE_SIZE") || 2_048,
      max_export_batch_size:
        Otel.SDK.Config.Env.integer("OTEL_BSP_MAX_EXPORT_BATCH_SIZE") || 512
    }

    Map.merge(base, overrides)
  end

  @spec build_span_limits(pillar :: keyword()) :: Otel.SDK.Trace.SpanLimits.t()
  defp build_span_limits(pillar) do
    overrides =
      pillar
      |> Keyword.get(:span_limits, %{})
      |> Enum.into(%{})

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
    pillar = Application.get_env(:otel_sdk, :metrics, [])

    %{
      resource: Otel.SDK.Resource.default(),
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
    case metrics_exporter(pillar) do
      :none -> []
      exporter -> [{Otel.SDK.Metrics.PeriodicExportingMetricReader, reader_config(pillar, exporter)}]
    end
  end

  @spec metrics_exporter(pillar :: keyword()) :: {module(), map()} | :none
  defp metrics_exporter(pillar) do
    cond do
      explicit = Keyword.get(pillar, :exporter) ->
        Otel.SDK.Config.Selector.metrics_exporter(explicit)

      from_env =
          Otel.SDK.Config.Env.enum("OTEL_METRICS_EXPORTER", [:otlp, :console, :none]) ->
        Otel.SDK.Config.Selector.metrics_exporter(from_env)

      true ->
        Otel.SDK.Config.Selector.metrics_exporter(:otlp)
    end
  end

  @spec reader_config(pillar :: keyword(), exporter :: {module(), map()}) :: map()
  defp reader_config(pillar, exporter) do
    overrides = Keyword.get(pillar, :reader_config, %{})

    base = %{
      exporter: exporter,
      export_interval_ms:
        Otel.SDK.Config.Env.duration_ms("OTEL_METRIC_EXPORT_INTERVAL") || 60_000,
      export_timeout_ms:
        Otel.SDK.Config.Env.timeout_ms("OTEL_METRIC_EXPORT_TIMEOUT") || 30_000
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
    pillar = Application.get_env(:otel_sdk, :logs, [])

    %{
      resource: Otel.SDK.Resource.default(),
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
  defp default_logs_processors(pillar) do
    case logs_exporter(pillar) do
      :none -> []
      exporter -> [{logs_processor_module(pillar), logs_processor_config(pillar, exporter)}]
    end
  end

  @spec logs_exporter(pillar :: keyword()) :: {module(), map()} | :none
  defp logs_exporter(pillar) do
    cond do
      explicit = Keyword.get(pillar, :exporter) ->
        Otel.SDK.Config.Selector.logs_exporter(explicit)

      from_env = Otel.SDK.Config.Env.enum("OTEL_LOGS_EXPORTER", [:otlp, :console, :none]) ->
        Otel.SDK.Config.Selector.logs_exporter(from_env)

      true ->
        Otel.SDK.Config.Selector.logs_exporter(:otlp)
    end
  end

  @spec logs_processor_module(pillar :: keyword()) :: module()
  defp logs_processor_module(pillar) do
    pillar
    |> Keyword.get(:processor, :batch)
    |> Otel.SDK.Config.Selector.logs_processor()
  end

  @spec logs_processor_config(pillar :: keyword(), exporter :: {module(), map()}) :: map()
  defp logs_processor_config(pillar, exporter) do
    overrides = Keyword.get(pillar, :processor_config, %{})

    base = %{
      exporter: exporter,
      scheduled_delay_ms:
        Otel.SDK.Config.Env.duration_ms("OTEL_BLRP_SCHEDULE_DELAY") || 1_000,
      export_timeout_ms:
        Otel.SDK.Config.Env.timeout_ms("OTEL_BLRP_EXPORT_TIMEOUT") || 30_000,
      max_queue_size: Otel.SDK.Config.Env.integer("OTEL_BLRP_MAX_QUEUE_SIZE") || 2_048,
      max_export_batch_size:
        Otel.SDK.Config.Env.integer("OTEL_BLRP_MAX_EXPORT_BATCH_SIZE") || 512
    }

    Map.merge(base, overrides)
  end

  @spec build_log_record_limits(pillar :: keyword()) :: Otel.SDK.Logs.LogRecordLimits.t()
  defp build_log_record_limits(pillar) do
    overrides =
      pillar
      |> Keyword.get(:log_record_limits, %{})
      |> Enum.into(%{})

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
end
