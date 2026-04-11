defmodule Otel.SDK.Trace.SpanCreator do
  @moduledoc """
  Orchestrates SDK span creation per spec L339.

  Pure function module — same role as opentelemetry-erlang's
  `otel_span_utils`. Called by the SDK Tracer.
  """

  @doc """
  Creates a span following the SDK creation flow.

  Returns `{span_ctx, span | nil}` where span is nil for dropped spans.
  """
  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          name :: String.t(),
          sampler :: Otel.SDK.Trace.Sampler.t(),
          id_generator :: module(),
          span_limits :: Otel.SDK.Trace.SpanLimits.t(),
          opts :: keyword()
        ) :: {Otel.API.Trace.SpanContext.t(), Otel.SDK.Trace.Span.t() | nil}
  def start_span(ctx, name, sampler, id_generator, span_limits, opts) do
    kind = Keyword.get(opts, :kind, :internal)
    attributes = Keyword.get(opts, :attributes, %{})
    links = Keyword.get(opts, :links, [])
    start_time = Keyword.get(opts, :start_time, System.system_time(:nanosecond))

    {span_ctx, parent_span_id, parent_is_remote} = new_span_ctx(ctx, id_generator, opts)

    trace_id = span_ctx.trace_id
    span_id = span_ctx.span_id

    {trace_flags, is_recording, sampler_attributes, tracestate} =
      sample(ctx, sampler, trace_id, links, name, kind, attributes)

    span_ctx = %Otel.API.Trace.SpanContext{
      span_ctx
      | trace_flags: trace_flags,
        tracestate: tracestate
    }

    if is_recording do
      merged_attributes =
        attributes
        |> Map.merge(sampler_attributes)
        |> apply_attribute_limits(span_limits)

      limited_links = Enum.take(links, span_limits.link_count_limit)

      span = %Otel.SDK.Trace.Span{
        trace_id: trace_id,
        span_id: span_id,
        tracestate: tracestate,
        parent_span_id: parent_span_id,
        parent_span_is_remote: parent_is_remote,
        name: name,
        kind: kind,
        start_time: start_time,
        attributes: merged_attributes,
        events: [],
        links: limited_links,
        trace_flags: trace_flags,
        is_recording: true
      }

      {span_ctx, span}
    else
      {span_ctx, nil}
    end
  end

  defp apply_attribute_limits(attributes, span_limits) do
    attributes
    |> Enum.take(span_limits.attribute_count_limit)
    |> Enum.map(fn {key, value} ->
      {key, truncate_value(value, span_limits.attribute_value_length_limit)}
    end)
    |> Map.new()
  end

  defp truncate_value(value, :infinity), do: value

  defp truncate_value(value, limit) when is_binary(value) and byte_size(value) > limit do
    String.slice(value, 0, limit)
  end

  defp truncate_value(value, limit) when is_list(value) do
    Enum.map(value, &truncate_value(&1, limit))
  end

  defp truncate_value(value, _limit), do: value

  defp new_span_ctx(ctx, id_generator, opts) do
    parent = Otel.API.Trace.current_span(ctx)
    is_root = Keyword.get(opts, :is_root, false)

    case {is_root, parent} do
      {true, _} ->
        root_span_ctx(id_generator)

      {_, %Otel.API.Trace.SpanContext{trace_id: 0}} ->
        root_span_ctx(id_generator)

      {_, %Otel.API.Trace.SpanContext{span_id: 0}} ->
        root_span_ctx(id_generator)

      {_, %Otel.API.Trace.SpanContext{} = parent_ctx} ->
        span_id = id_generator.generate_span_id()

        {
          %Otel.API.Trace.SpanContext{
            trace_id: parent_ctx.trace_id,
            span_id: span_id,
            tracestate: parent_ctx.tracestate,
            is_remote: false
          },
          parent_ctx.span_id,
          parent_ctx.is_remote
        }
    end
  end

  defp root_span_ctx(id_generator) do
    trace_id = id_generator.generate_trace_id()
    span_id = id_generator.generate_span_id()

    {
      %Otel.API.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        is_remote: false
      },
      nil,
      nil
    }
  end

  defp sample(ctx, sampler, trace_id, links, name, kind, attributes) do
    {decision, new_attributes, tracestate} =
      Otel.SDK.Trace.Sampler.should_sample(
        sampler,
        ctx,
        trace_id,
        links,
        name,
        kind,
        attributes
      )

    case decision do
      :drop -> {0, false, new_attributes, tracestate}
      :record_only -> {0, true, new_attributes, tracestate}
      :record_and_sample -> {1, true, new_attributes, tracestate}
    end
  end
end
