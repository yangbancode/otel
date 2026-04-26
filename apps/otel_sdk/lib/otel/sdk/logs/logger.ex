defmodule Otel.SDK.Logs.Logger do
  @moduledoc """
  SDK implementation of the Logger behaviour.

  Emits log records by dispatching to all registered processors.
  Populates trace context from the resolved Context and sets
  observed_timestamp when not provided.

  All functions are safe for concurrent use.

  ## LogRecord limits

  `build_log_record/3` composes the two
  `Otel.SDK.Logs.LogRecordLimits` helpers in order —
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
  """

  require Logger

  @behaviour Otel.API.Logs.Logger

  @impl true
  @spec emit(
          logger :: Otel.API.Logs.Logger.t(),
          ctx :: Otel.API.Ctx.t(),
          log_record :: Otel.API.Logs.LogRecord.t()
        ) :: :ok
  def emit({_module, config}, ctx, log_record) do
    # Spec L243-L252: before processing a log record, the
    # implementation MUST apply LoggerConfig filters in this order:
    # (1) Logger disabled → drop, (2) minimum_severity, (3) trace_based.
    if logger_config_drops_emit?(config.logger_config, log_record, ctx) do
      :ok
    else
      record = log_record |> apply_exception_attributes() |> build_log_record(config, ctx)
      processors = get_processors(config)

      Enum.each(processors, fn {processor, processor_config} ->
        processor.on_emit(record, ctx, processor_config)
      end)
    end
  end

  @impl true
  @spec enabled?(
          logger :: Otel.API.Logs.Logger.t(),
          opts :: Otel.API.Logs.Logger.enabled_opts()
        ) :: boolean()
  def enabled?({_module, config}, opts) do
    processors = get_processors(config)
    # The API dispatcher always injects `:ctx`, but a direct SDK
    # caller may omit it. Mirror the API's fallback to the current
    # Context so the processor's `enabled?/4` always sees a valid
    # ctx (spec §LogRecordProcessor L425-L426).
    {ctx, processor_opts} = Keyword.pop_lazy(opts, :ctx, &Otel.API.Ctx.current/0)

    cond do
      # Spec L256-L257: MUST return false when there are no
      # registered LogRecordProcessors.
      processors == [] ->
        false

      # Spec L258-L260: MUST return false when LoggerConfig.enabled
      # is false (Status: Development).
      not config.logger_config.enabled ->
        false

      # Spec L261-L263: MUST return false when severity_number is
      # specified (not 0) and < minimum_severity (Status: Development).
      logger_config_severity_filters?(config.logger_config, processor_opts) ->
        false

      # Spec L264-L266: MUST return false when trace_based is true
      # and ctx is associated with an unsampled trace (Development).
      logger_config_trace_filters?(config.logger_config, ctx) ->
        false

      # Spec L267-L268: MUST return false when all processors
      # implement Enabled and all return false.
      true ->
        not Enum.all?(processors, fn {processor, processor_config} ->
          function_exported?(processor, :enabled?, 4) and
            not processor.enabled?(ctx, config.scope, processor_opts, processor_config)
        end)
    end
  end

  # Spec L243-L252 emit-time filter rules. Returns true when the
  # record should be dropped per LoggerConfig.
  @spec logger_config_drops_emit?(
          logger_config :: Otel.SDK.Logs.LoggerConfig.t(),
          log_record :: Otel.API.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t()
        ) :: boolean()
  defp logger_config_drops_emit?(
         %Otel.SDK.Logs.LoggerConfig{
           enabled: enabled,
           minimum_severity: min_sev,
           trace_based: trace_based
         },
         %Otel.API.Logs.LogRecord{severity_number: sev},
         ctx
       ) do
    cond do
      not enabled -> true
      min_sev > 0 and sev > 0 and sev < min_sev -> true
      trace_based -> ctx_has_unsampled_trace?(ctx)
      true -> false
    end
  end

  @spec logger_config_severity_filters?(
          logger_config :: Otel.SDK.Logs.LoggerConfig.t(),
          opts :: Otel.SDK.Logs.LogRecordProcessor.enabled_opts()
        ) :: boolean()
  defp logger_config_severity_filters?(%Otel.SDK.Logs.LoggerConfig{minimum_severity: 0}, _opts),
    do: false

  defp logger_config_severity_filters?(
         %Otel.SDK.Logs.LoggerConfig{minimum_severity: min_sev},
         opts
       ) do
    case Keyword.get(opts, :severity_number, 0) do
      0 -> false
      sev when sev < min_sev -> true
      _ -> false
    end
  end

  @spec logger_config_trace_filters?(
          logger_config :: Otel.SDK.Logs.LoggerConfig.t(),
          ctx :: Otel.API.Ctx.t()
        ) :: boolean()
  defp logger_config_trace_filters?(%Otel.SDK.Logs.LoggerConfig{trace_based: false}, _ctx),
    do: false

  defp logger_config_trace_filters?(%Otel.SDK.Logs.LoggerConfig{trace_based: true}, ctx),
    do: ctx_has_unsampled_trace?(ctx)

  # Spec L213-L217: a log record is associated with an unsampled
  # trace when it has a valid SpanId and TraceFlags' SAMPLED bit
  # is unset. Records without trace context bypass this filter.
  @spec ctx_has_unsampled_trace?(ctx :: Otel.API.Ctx.t()) :: boolean()
  defp ctx_has_unsampled_trace?(ctx) do
    %Otel.API.Trace.SpanContext{span_id: span_id, trace_flags: trace_flags} =
      Otel.API.Trace.current_span(ctx)

    Otel.API.Trace.SpanId.valid?(span_id) and Bitwise.band(trace_flags, 1) == 0
  end

  @spec get_processors(config :: map()) ::
          [{module(), Otel.SDK.Logs.LogRecordProcessor.config()}]
  defp get_processors(config) do
    :persistent_term.get(config.processors_key, [])
  end

  # --- Private ---

  @spec build_log_record(
          log_record :: Otel.API.Logs.LogRecord.t(),
          config :: map(),
          ctx :: Otel.API.Ctx.t()
        ) :: Otel.SDK.Logs.LogRecord.t()
  defp build_log_record(%Otel.API.Logs.LogRecord{} = log_record, config, ctx) do
    now = System.system_time(:nanosecond)

    # Spec data-model.md L208-L213 (`bridge from non-OTel source`
    # path): if the caller pre-stamped trace context on the API
    # LogRecord struct, use those values verbatim. Otherwise
    # (the typical emit-from-Context path) derive from the
    # resolved Context.
    {trace_id, span_id, trace_flags} = resolve_trace_context(log_record, ctx)

    {limited_record, dropped_attributes_count} =
      Otel.SDK.Logs.LogRecordLimits.apply(log_record, config.log_record_limits)

    log_limits_applied(
      dropped_attributes_count,
      log_record.attributes != limited_record.attributes
    )

    observed_timestamp =
      case log_record.observed_timestamp do
        0 -> now
        ts -> ts
      end

    %Otel.SDK.Logs.LogRecord{
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

  # If the caller stamped a valid trace context on the API
  # LogRecord (bridge path), prefer it. The all-zero proto3
  # default signals "no caller-supplied context" via
  # `TraceId.valid?/1` + `SpanId.valid?/1` returning false on
  # the all-zero opaque sentinels; fall back to deriving from
  # `ctx`.
  @spec resolve_trace_context(
          log_record :: Otel.API.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t()
        ) ::
          {Otel.API.Trace.TraceId.t(), Otel.API.Trace.SpanId.t(),
           Otel.API.Trace.SpanContext.trace_flags()}
  defp resolve_trace_context(%Otel.API.Logs.LogRecord{} = log_record, ctx) do
    if Otel.API.Trace.TraceId.valid?(log_record.trace_id) and
         Otel.API.Trace.SpanId.valid?(log_record.span_id) do
      {log_record.trace_id, log_record.span_id, log_record.trace_flags}
    else
      extract_trace_context(ctx)
    end
  end

  # When both a count drop and a value truncation occur in
  # the same record, the message reports only the drop —
  # apply/2's black-box signature does not let the caller
  # distinguish the two effects independently. The
  # truncate-only branch fires only when no drop happened.
  @spec log_limits_applied(dropped :: non_neg_integer(), changed? :: boolean()) :: :ok
  defp log_limits_applied(0, false), do: :ok

  defp log_limits_applied(dropped, _changed?) when dropped > 0 do
    Logger.warning("LogRecord limits applied: dropped #{dropped} attribute(s)")
    :ok
  end

  defp log_limits_applied(_dropped, true) do
    Logger.warning("LogRecord limits applied: truncated value(s) exceeding length limit")
    :ok
  end

  # Spec sdk.md L228-L230: *"If an Exception is provided, the
  # SDK MUST by default set attributes from the exception on
  # the LogRecord with the conventions outlined in the
  # exception semantic conventions"* (see
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
  # on key conflict (`Otel.LoggerHandler` follows this pattern,
  # `apps/otel_logger_handler/lib/otel/logger_handler.ex`).
  @spec apply_exception_attributes(log_record :: Otel.API.Logs.LogRecord.t()) ::
          Otel.API.Logs.LogRecord.t()
  defp apply_exception_attributes(
         %Otel.API.Logs.LogRecord{exception: %{__exception__: true} = exception} = log_record
       ) do
    exception_attrs = %{
      "exception.type" => exception.__struct__ |> Atom.to_string(),
      "exception.message" => Exception.message(exception)
    }

    merged = Map.merge(exception_attrs, log_record.attributes)
    %{log_record | attributes: merged}
  end

  defp apply_exception_attributes(%Otel.API.Logs.LogRecord{} = log_record), do: log_record

  @spec extract_trace_context(ctx :: Otel.API.Ctx.t()) ::
          {Otel.API.Trace.TraceId.t(), Otel.API.Trace.SpanId.t(),
           Otel.API.Trace.SpanContext.trace_flags()}
  defp extract_trace_context(ctx) do
    %Otel.API.Trace.SpanContext{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags
    } = Otel.API.Trace.current_span(ctx)

    {trace_id, span_id, trace_flags}
  end
end
