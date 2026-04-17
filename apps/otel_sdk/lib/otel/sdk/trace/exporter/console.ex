defmodule Otel.SDK.Trace.Exporter.Console do
  @moduledoc """
  Console exporter for debugging and learning purposes.

  Outputs spans to stdout in human-readable format. Not recommended
  for production use. The output format is not standardized and can
  change at any time.

  If a standardized format for exporting traces to stdout is desired,
  consider using the File Exporter, if available.
  """

  @behaviour Otel.SDK.Trace.SpanExporter

  @spec init(config :: term()) :: {:ok, Otel.SDK.Trace.SpanExporter.state()} | :ignore
  @impl true
  def init(config), do: {:ok, config}

  @spec export(
          spans :: [Otel.SDK.Trace.Span.t()],
          resource :: map(),
          state :: Otel.SDK.Trace.SpanExporter.state()
        ) :: :ok | :error
  @impl true
  def export(spans, _resource, _state) do
    Enum.each(spans, fn span ->
      IO.puts(format_span(span))
    end)

    :ok
  end

  @spec shutdown(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def shutdown(_state), do: :ok

  @spec format_span(span :: Otel.SDK.Trace.Span.t()) :: String.t()
  defp format_span(span) do
    trace_id = Otel.API.Trace.TraceId.to_hex(span.trace_id)
    span_id = Otel.API.Trace.SpanId.to_hex(span.span_id)

    parent =
      case span.parent_span_id do
        nil -> "none"
        %Otel.API.Trace.SpanId{} = id -> Otel.API.Trace.SpanId.to_hex(id)
      end

    "[otel] #{span.name} trace_id=#{trace_id} span_id=#{span_id} parent=#{parent} kind=#{span.kind} status=#{inspect(span.status)} attributes=#{format_attributes(span.attributes)}"
  end

  @spec format_attributes(attributes :: [Otel.API.Common.Attribute.t()]) :: String.t()
  defp format_attributes(attributes) do
    rendered =
      Enum.map_join(attributes, ", ", fn %Otel.API.Common.Attribute{key: k, value: v} ->
        "#{k}=#{display_any_value(v)}"
      end)

    "[#{rendered}]"
  end

  @spec display_any_value(value :: Otel.API.Common.AnyValue.t()) :: String.t()
  defp display_any_value(%Otel.API.Common.AnyValue{type: :string, value: v}), do: v
  defp display_any_value(%Otel.API.Common.AnyValue{type: :bool, value: v}), do: to_string(v)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :int, value: v}), do: to_string(v)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :double, value: v}), do: to_string(v)

  defp display_any_value(%Otel.API.Common.AnyValue{type: :bytes, value: v}),
    do: "<#{byte_size(v)} bytes>"

  defp display_any_value(%Otel.API.Common.AnyValue{type: :array, value: vs}), do: inspect(vs)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :kvlist, value: m}), do: inspect(m)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :empty}), do: "nil"
end
