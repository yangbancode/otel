defmodule Otel.SDK.Logs.Exporter.Console do
  @moduledoc """
  Console exporter for log records debugging.

  Outputs log records to stdout in human-readable format.
  Not recommended for production use. The output format is
  not standardized and can change at any time.

  By default the stdout exporter SHOULD be paired with a
  SimpleLogRecordProcessor.
  """

  @behaviour Otel.SDK.Logs.LogRecordExporter

  @impl true
  @spec init(config :: term()) :: {:ok, Otel.SDK.Logs.LogRecordExporter.state()}
  def init(config), do: {:ok, config}

  @impl true
  @spec export(
          log_records :: [map()],
          state :: Otel.SDK.Logs.LogRecordExporter.state()
        ) :: :ok
  def export(log_records, _state) do
    Enum.each(log_records, fn record ->
      IO.puts(format_log_record(record))
    end)

    :ok
  end

  @impl true
  @spec force_flush(state :: Otel.SDK.Logs.LogRecordExporter.state()) :: :ok
  def force_flush(_state), do: :ok

  @impl true
  @spec shutdown(state :: Otel.SDK.Logs.LogRecordExporter.state()) :: :ok
  def shutdown(_state), do: :ok

  @spec format_log_record(record :: map()) :: String.t()
  defp format_log_record(record) do
    severity = format_severity(record)
    scope = format_scope(record)
    body = format_body(Map.get(record, :body))
    attrs = format_attributes(Map.get(record, :attributes, []))
    trace = format_trace(record)

    "[otel] #{severity} #{scope}#{trace} body=#{body} attributes=#{attrs}"
  end

  @spec format_severity(record :: map()) :: String.t()
  defp format_severity(record) do
    text = Map.get(record, :severity_text)
    number = Map.get(record, :severity_number)

    case {text, number} do
      {nil, nil} -> "UNSPECIFIED"
      {nil, n} -> "severity=#{n}"
      {t, _} -> t
    end
  end

  @spec format_scope(record :: map()) :: String.t()
  defp format_scope(%{scope: %{name: name}}) when name != "", do: "scope=#{name} "
  defp format_scope(_record), do: ""

  @spec format_trace(record :: map()) :: String.t()
  defp format_trace(%{
         trace_id: %Otel.API.Trace.TraceId{} = tid,
         span_id: %Otel.API.Trace.SpanId{} = sid
       }) do
    case {Otel.API.Trace.TraceId.valid?(tid), Otel.API.Trace.SpanId.valid?(sid)} do
      {true, true} ->
        " trace=#{Otel.API.Trace.TraceId.to_hex(tid)} span=#{Otel.API.Trace.SpanId.to_hex(sid)}"

      _ ->
        ""
    end
  end

  defp format_trace(_record), do: ""

  @spec format_body(body :: Otel.API.Common.AnyValue.t() | nil) :: String.t()
  defp format_body(nil), do: "nil"
  defp format_body(%Otel.API.Common.AnyValue{} = v), do: display_any_value(v)

  @spec format_attributes(attrs :: [Otel.API.Common.Attribute.t()]) :: String.t()
  defp format_attributes([]), do: "[]"

  defp format_attributes(attrs) when is_list(attrs) do
    rendered =
      Enum.map_join(attrs, ", ", fn %Otel.API.Common.Attribute{key: k, value: v} ->
        "#{k}=#{display_any_value(v)}"
      end)

    "[#{rendered}]"
  end

  @spec display_any_value(value :: Otel.API.Common.AnyValue.t()) :: String.t()
  defp display_any_value(%Otel.API.Common.AnyValue{type: :string, value: v}), do: v
  defp display_any_value(%Otel.API.Common.AnyValue{type: :int, value: v}), do: to_string(v)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :double, value: v}), do: to_string(v)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :bool, value: v}), do: to_string(v)

  defp display_any_value(%Otel.API.Common.AnyValue{type: :bytes, value: v}),
    do: "<#{byte_size(v)} bytes>"

  defp display_any_value(%Otel.API.Common.AnyValue{type: :array, value: v}), do: inspect(v)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :kvlist, value: v}), do: inspect(v)
  defp display_any_value(%Otel.API.Common.AnyValue{type: :empty}), do: "nil"
end
