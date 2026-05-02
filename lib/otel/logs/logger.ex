defmodule Otel.Logs.Logger do
  @moduledoc """
  SDK implementation of the `Otel.Logs.Logger` behaviour
  (`logs/sdk.md` §Logger).

  Emits log records by dispatching to all registered processors.
  Populates trace context from the resolved Context and sets
  observed_timestamp when not provided.

  All functions are safe for concurrent use, satisfying spec
  `logs/api.md` L172-L176 (Status: Stable, #4885) — *"Logger —
  all methods MUST be documented that implementations need to
  be safe for concurrent use by default."*

  ## Public API

  | Function | Role |
  |---|---|
  | `emit/3` | **SDK** (OTel API MUST) — `logs/api.md` L111-L131 + `logs/sdk.md` §Emit |
  | `enabled?/2` | **SDK** (OTel API SHOULD) — `logs/api.md` L133-L154 + `logs/sdk.md` §Enabled |

  ## LogRecord limits

  `build_log_record/3` composes the two
  `Otel.Logs.LogRecordLimits` helpers in order —
  `truncate_attributes/2` first (so dropped count is taken
  on the post-truncation map), then `drop_attributes/2`.
  The `dropped_attributes_count` field on the record is the
  size delta across the drop step, satisfying
  `mapping-to-non-otlp.md` L73-79 (*"OpenTelemetry dropped
  attributes count MUST be reported as a key-value pair ...
  `otel.dropped_attributes_count`"*).

  Per `logs/sdk.md` L345-348, a single `Logger.warning/1` is
  emitted per LogRecord whenever either limit took effect.
  The MUST *"at most once per LogRecord"* is satisfied
  structurally — `build_log_record/3` runs once per
  `emit/3` call.

  ### Self-reference

  The warning re-enters the OTel pipeline whenever
  `Otel.LoggerHandler` is installed. The re-entered record
  carries a single short-string attribute payload, well
  below the default limits, so it produces no additional
  warning — the recursion is bounded at depth 1. Matches
  `opentelemetry-erlang`: `otel_log_handler.erl` L233 emits
  `?LOG_WARNING(...)` on exporter failure, and
  `otel_exporter.erl` / `otel_configuration.erl` use
  `?LOG_WARNING` / `?LOG_INFO` throughout — none filter
  their own warnings out of the OTel bridge.

  ## References

  - OTel Logs SDK §Logger: `opentelemetry-specification/specification/logs/sdk.md`
  - OTel Logs API §Logger: `opentelemetry-specification/specification/logs/api.md` L99-L155
  - OTLP `mapping-to-non-otlp.md` §Dropped Attributes Count: L73-L79
  """

  require Logger

  @typedoc """
  A Logger struct.

  Configuration is held by the LoggerProvider; the Logger
  carries the runtime config map (scope, resource,
  log_record_limits, processors_key) that emit/enabled?
  operations need.
  """
  @type t :: %__MODULE__{config: map()}

  defstruct config: %{}

  @typedoc """
  One option accepted by `enabled?/2`, per §Enabled
  (`logs/api.md` L137-L142):

  - `:severity_number` — severity the caller would emit
    (0..24, L141)
  - `:event_name` — event name the caller would emit (L142)
  - `:ctx` — evaluation context (L137-L140; defaults to
    `Otel.Ctx.current/0` when omitted)

  Unlike `Otel.Trace.Tracer.enabled_opt/0` which is left
  open (`keyword()`) because the Trace spec does not define
  common keys, Logs §Enabled enumerates these three keys at
  the API level — enumeration is appropriate here because it
  mirrors a spec contract, not an SDK assumption
  (`.claude/rules/code-conventions.md` §Layer independence).
  """
  @type enabled_opt ::
          {:severity_number, Otel.Logs.severity_number()}
          | {:event_name, String.t()}
          | {:ctx, Otel.Ctx.t()}

  @typedoc "A keyword list of `enabled_opt/0` values."
  @type enabled_opts :: [enabled_opt()]

  @doc """
  Emit a LogRecord (`logs/api.md` L111-L131) using the implicit
  (process-local) context. Per L119-L123 *"When implicit Context
  is supported, then this parameter SHOULD be optional and if
  unspecified then MUST use current Context"*.
  """
  @spec emit(logger :: t(), log_record :: Otel.Logs.LogRecord.t()) :: :ok
  def emit(%__MODULE__{} = logger, log_record \\ %Otel.Logs.LogRecord{}) do
    emit(logger, Otel.Ctx.current(), log_record)
  end

  @doc """
  Emit a LogRecord (`logs/api.md` L111-L131) with an explicit
  context.

  Dispatches the limited record to every registered processor.
  """
  @spec emit(
          logger :: t(),
          ctx :: Otel.Ctx.t(),
          log_record :: Otel.Logs.LogRecord.t()
        ) :: :ok
  def emit(%__MODULE__{config: config}, ctx, log_record) do
    record = log_record |> apply_exception_attributes() |> build_log_record(config, ctx)
    processors = get_processors(config)

    Enum.each(processors, fn {processor, processor_config} ->
      processor.on_emit(record, ctx, processor_config)
    end)
  end

  @doc """
  **SDK** (OTel API SHOULD) — Enabled
  (`logs/api.md` L133-L154 + `logs/sdk.md` §Enabled L256-L268).

  Returns false when no processors are registered, or when every
  processor implementing `enabled?/4` returns false. The
  Development-status `LoggerConfig` filter legs (L259-L266 —
  enabled / minimum_severity / trace_based) are deferred per the
  project's Stable-only policy, mirroring how
  `Otel.Trace.Tracer.enabled?/2` defers `TracerConfig`.
  """
  @spec enabled?(
          logger :: t(),
          opts :: enabled_opts()
        ) :: boolean()
  def enabled?(%__MODULE__{config: config}, opts \\ []) do
    processors = get_processors(config)

    # Spec L256 + L258 (header + bullet): MUST return false when
    # there are no registered LogRecordProcessors.
    if processors == [] do
      false
    else
      # The API dispatcher always injects `:ctx`, but a direct
      # SDK caller may omit it. Mirror the API's fallback to the
      # current Context so the processor's `enabled?/4` always
      # sees a valid ctx (spec §LogRecordProcessor L425-L426).
      {ctx, processor_opts} = Keyword.pop_lazy(opts, :ctx, &Otel.Ctx.current/0)

      # Spec L267-L268: MUST return false when all processors
      # implement Enabled and all return false.
      not Enum.all?(processors, fn {processor, processor_config} ->
        function_exported?(processor, :enabled?, 4) and
          not processor.enabled?(ctx, config.scope, processor_opts, processor_config)
      end)
    end
  end

  @spec get_processors(config :: map()) ::
          [{module(), Otel.Logs.LogRecordProcessor.config()}]
  defp get_processors(config) do
    :persistent_term.get(config.processors_key, [])
  end

  # --- Private ---

  @spec build_log_record(
          log_record :: Otel.Logs.LogRecord.t(),
          config :: map(),
          ctx :: Otel.Ctx.t()
        ) :: Otel.Logs.LogRecord.t()
  defp build_log_record(%Otel.Logs.LogRecord{} = log_record, config, ctx) do
    now = System.system_time(:nanosecond)

    %Otel.Trace.SpanContext{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags
    } = Otel.Trace.current_span(ctx)

    {limited_record, dropped_attributes_count} =
      Otel.Logs.LogRecordLimits.apply(log_record, config.log_record_limits)

    warn_log_record_limits_applied(
      dropped_attributes_count,
      log_record.attributes != limited_record.attributes
    )

    observed_timestamp =
      case log_record.observed_timestamp do
        0 -> now
        ts -> ts
      end

    %Otel.Logs.LogRecord{
      timestamp: log_record.timestamp,
      observed_timestamp: observed_timestamp,
      severity_number: log_record.severity_number,
      severity_text: log_record.severity_text,
      body: log_record.body,
      event_name: log_record.event_name,
      attributes: limited_record.attributes,
      dropped_attributes_count: dropped_attributes_count,
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags,
      scope: config.scope,
      resource: config.resource
    }
  end

  # When both a count drop and a value truncation occur in
  # the same record, the message reports only the drop —
  # apply/2's black-box signature does not let the caller
  # distinguish the two effects independently. The
  # truncate-only branch fires only when no drop happened.
  @spec warn_log_record_limits_applied(dropped :: non_neg_integer(), changed? :: boolean()) :: :ok
  defp warn_log_record_limits_applied(0, false), do: :ok

  defp warn_log_record_limits_applied(dropped, _changed?) when dropped > 0 do
    Logger.warning(
      "Otel.Logs.Logger: log record limits applied — dropped #{dropped} " <>
        "attribute#{if dropped == 1, do: "", else: "s"}"
    )

    :ok
  end

  defp warn_log_record_limits_applied(_dropped, true) do
    Logger.warning(
      "Otel.Logs.Logger: log record limits applied — truncated value(s) exceeding length limit"
    )

    :ok
  end

  # Spec sdk.md L228-L232: *"If an Exception is provided, the
  # SDK MUST by default set attributes from the exception on
  # the LogRecord with the conventions outlined in the
  # exception semantic conventions. User-provided attributes
  # MUST take precedence and MUST NOT be overwritten by
  # exception-derived attributes."* (see
  # `semantic-conventions/docs/exceptions/exceptions-logs.md`):
  # `exception.type`, `exception.message`, `exception.stacktrace`.
  #
  # We extract `exception.type` and `exception.message` from
  # the Elixir exception struct here. `exception.stacktrace` is
  # NOT extracted because Elixir/Erlang exceptions do not carry
  # a stacktrace on the struct — `__STACKTRACE__` is a separate
  # value bound at the catch site. Callers who have a stacktrace
  # set `attributes["exception.stacktrace"]` themselves; that
  # attribute survives `Map.merge/2` because user attributes win
  # on key conflict (the L231-L232 user-precedence MUST), which
  # `Otel.LoggerHandler` relies on
  # (`apps/otel_logger_handler/lib/otel/logger_handler.ex`).
  @spec apply_exception_attributes(log_record :: Otel.Logs.LogRecord.t()) ::
          Otel.Logs.LogRecord.t()
  defp apply_exception_attributes(
         %Otel.Logs.LogRecord{exception: %{__exception__: true} = exception} = log_record
       ) do
    exception_attrs = %{
      "exception.type" => exception.__struct__ |> Atom.to_string(),
      "exception.message" => Exception.message(exception)
    }

    merged = Map.merge(exception_attrs, log_record.attributes)
    %{log_record | attributes: merged}
  end

  defp apply_exception_attributes(%Otel.Logs.LogRecord{} = log_record), do: log_record
end
