defmodule Otel.SDK.Logs.Logger do
  @moduledoc """
  SDK implementation of the Logger behaviour.

  Emits log records by dispatching to all registered processors.
  Populates trace context from the resolved Context and sets
  observed_timestamp when not provided.

  All functions are safe for concurrent use.
  """

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

    limited_attrs =
      Otel.SDK.Logs.LogRecord.Limits.apply(log_record.attributes, config.log_record_limits)

    dropped_count = map_size(log_record.attributes) - map_size(limited_attrs)

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
