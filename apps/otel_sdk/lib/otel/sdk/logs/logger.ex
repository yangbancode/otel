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
          log_record :: Otel.API.Logs.Logger.log_record()
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
          opts :: keyword()
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
          log_record :: Otel.API.Logs.Logger.log_record(),
          config :: map(),
          ctx :: Otel.API.Ctx.t()
        ) :: map()
  defp build_log_record(log_record, config, ctx) do
    now = System.system_time(:nanosecond)
    {trace_id, span_id, trace_flags} = extract_trace_context(ctx)

    attributes = Map.get(log_record, :attributes, %{})

    {limited_attrs, dropped_count} =
      Otel.SDK.Logs.LogRecordLimits.apply(attributes, config.log_record_limits)

    log_record
    |> Map.put_new(:observed_timestamp, now)
    |> Map.put_new(:timestamp, nil)
    |> Map.put_new(:severity_number, nil)
    |> Map.put_new(:severity_text, nil)
    |> Map.put_new(:body, nil)
    |> Map.put(:attributes, limited_attrs)
    |> Map.put(:dropped_attributes_count, dropped_count)
    |> Map.put_new(:event_name, nil)
    |> Map.put(:trace_id, trace_id)
    |> Map.put(:span_id, span_id)
    |> Map.put(:trace_flags, trace_flags)
    |> Map.put(:scope, config.scope)
    |> Map.put(:resource, config.resource)
  end

  @spec apply_exception_attributes(log_record :: map()) :: map()
  defp apply_exception_attributes(%{exception: %{__exception__: true} = exception} = log_record) do
    exception_attrs = %{
      :"exception.type" => exception.__struct__ |> Atom.to_string(),
      :"exception.message" => Exception.message(exception)
    }

    user_attrs = Map.get(log_record, :attributes, %{})
    merged = Map.merge(exception_attrs, user_attrs)
    Map.put(log_record, :attributes, merged)
  end

  defp apply_exception_attributes(log_record), do: log_record

  @spec extract_trace_context(ctx :: Otel.API.Ctx.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  defp extract_trace_context(ctx) do
    %Otel.API.Trace.SpanContext{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags
    } = Otel.API.Trace.current_span(ctx)

    {trace_id, span_id, trace_flags}
  end
end
