defmodule Otel.SDK.Trace.SpanExporter.Console do
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
          resource :: Otel.SDK.Resource.t(),
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

  @spec force_flush(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def force_flush(_state), do: :ok

  @spec format_span(span :: Otel.SDK.Trace.Span.t()) :: String.t()
  defp format_span(span) do
    trace_id = Otel.API.Trace.TraceId.to_hex(span.trace_id)
    span_id = Otel.API.Trace.SpanId.to_hex(span.span_id)

    parent =
      case span.parent_span_id do
        nil -> "none"
        id -> Otel.API.Trace.SpanId.to_hex(id)
      end

    "[otel] #{span.name} trace_id=#{trace_id} span_id=#{span_id} parent=#{parent} kind=#{span.kind} status=#{inspect(span.status)} attributes=#{inspect(span.attributes)}"
  end
end
