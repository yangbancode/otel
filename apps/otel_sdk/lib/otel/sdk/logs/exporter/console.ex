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
    body = inspect(Map.get(record, :body))
    attrs = inspect(Map.get(record, :attributes, %{}))
    trace = format_trace(record)

    "[otel] #{severity} #{scope}#{trace} body=#{body} attributes=#{attrs}"
  end

  @spec format_severity(record :: map()) :: String.t()
  defp format_severity(record) do
    text = Map.get(record, :severity_text, "")
    number = Map.get(record, :severity_number, 0)

    case {text, number} do
      {"", 0} -> "UNSPECIFIED"
      {"", n} -> "severity=#{n}"
      {t, _} -> t
    end
  end

  @spec format_scope(record :: map()) :: String.t()
  defp format_scope(%{scope: %{name: name}}) when name != "", do: "scope=#{name} "
  defp format_scope(_record), do: ""

  @spec format_trace(record :: map()) :: String.t()
  defp format_trace(%{trace_id: trace_id, span_id: span_id})
       when trace_id != 0 and span_id != 0 do
    tid = trace_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")
    sid = span_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(16, "0")
    " trace=#{tid} span=#{sid}"
  end

  defp format_trace(_record), do: ""
end
