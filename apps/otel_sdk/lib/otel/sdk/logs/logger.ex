defmodule Otel.SDK.Logs.Logger do
  @moduledoc """
  SDK implementation of the Logger behaviour.

  Emits log records by dispatching to all registered processors.
  Populates trace context from the resolved Context and sets
  observed_timestamp when not provided.

  All functions are safe for concurrent use.

  ## LogRecord limits

  `build_log_record/3` composes the two
  `Otel.SDK.Logs.LogRecord.Limits` helpers in order —
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
    record = log_record |> apply_exception_attributes() |> build_log_record(config, ctx)
    processors = get_processors(config)

    Enum.each(processors, fn {processor, processor_config} ->
      processor.on_emit(record, processor_config)
    end)
  end

  @impl true
  @spec enabled?(
          logger :: Otel.API.Logs.Logger.t(),
          opts :: Otel.API.Logs.Logger.enabled_opts()
        ) :: boolean()
  def enabled?({_module, config}, opts) do
    processors = get_processors(config)

    case processors do
      [] ->
        false

      _ ->
        not Enum.all?(processors, fn {processor, processor_config} ->
          function_exported?(processor, :enabled?, 2) and
            not processor.enabled?(opts, processor_config)
        end)
    end
  end

  @spec get_processors(config :: map()) :: [{module(), map()}]
  defp get_processors(config) do
    :persistent_term.get(config.processors_key, [])
  end

  # --- Private ---

  @spec build_log_record(
          log_record :: Otel.API.Logs.LogRecord.t(),
          config :: map(),
          ctx :: Otel.API.Ctx.t()
        ) :: map()
  defp build_log_record(%Otel.API.Logs.LogRecord{} = log_record, config, ctx) do
    now = System.system_time(:nanosecond)
    {trace_id, span_id, trace_flags} = extract_trace_context(ctx)

    limits = config.log_record_limits

    truncated_attrs =
      Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(
        log_record.attributes,
        limits.attribute_value_length_limit
      )

    limited_attrs =
      Otel.SDK.Logs.LogRecord.Limits.drop_attributes(
        truncated_attrs,
        limits.attribute_count_limit
      )

    dropped_count = map_size(truncated_attrs) - map_size(limited_attrs)
    log_limits_applied(dropped_count, truncated_attrs != log_record.attributes)

    observed_timestamp =
      case log_record.observed_timestamp do
        0 -> now
        ts -> ts
      end

    %{
      timestamp: log_record.timestamp,
      observed_timestamp: observed_timestamp,
      severity_number: log_record.severity_number,
      severity_text: log_record.severity_text,
      body: log_record.body,
      event_name: log_record.event_name,
      attributes: limited_attrs,
      dropped_attributes_count: dropped_count,
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags,
      scope: config.scope,
      resource: config.resource
    }
  end

  @spec log_limits_applied(dropped :: non_neg_integer(), truncated? :: boolean()) :: :ok
  defp log_limits_applied(0, false), do: :ok

  defp log_limits_applied(dropped, truncated?) do
    parts =
      [
        dropped > 0 && "dropped #{dropped} attribute(s)",
        truncated? && "truncated value(s) exceeding length limit"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    Logger.warning("LogRecord limits applied: #{parts}")
    :ok
  end

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
          {Otel.API.Trace.TraceId.t(), Otel.API.Trace.SpanId.t(), non_neg_integer()}
  defp extract_trace_context(ctx) do
    %Otel.API.Trace.SpanContext{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags
    } = Otel.API.Trace.current_span(ctx)

    {trace_id, span_id, trace_flags}
  end
end
