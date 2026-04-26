defmodule Otel.SDK.Logs.LogRecordExporter.Console do
  @moduledoc """
  Standard-output `LogRecordExporter` for debugging
  (`logs/sdk_exporters/stdout.md`).

  Outputs each `Otel.SDK.Logs.LogRecord` to stdout in a
  human-readable single-line format. Spec L16-L18 — *"This
  exporter is intended for debugging and learning purposes.
  It is not recommended for production use. The output format
  is not standardized and can change at any time."*

  Spec L33-L34 — by default this exporter SHOULD be paired
  with `Otel.SDK.Logs.LogRecordProcessor.Simple`.

  ## Output format

  Single line per record, prefixed with `[otel]`:

      [otel] <severity> [scope=<name> ][trace=<hex> span=<hex> ]body=<inspect> attributes=<inspect>

  - **severity** — `severity_text` if non-empty;
    `severity=<n>` when only `severity_number` is set;
    `UNSPECIFIED` when both are zero (proto3 default).
  - **scope** — emitted only when `scope.name` is non-empty.
  - **trace context** — emitted only when both `trace_id` and
    `span_id` are valid (`Otel.API.Trace.TraceId.valid?/1` and
    `Otel.API.Trace.SpanId.valid?/1`). When no Context is
    active, `Otel.SDK.Logs.LogRecord` defaults both to the
    invalid sentinel and the trace context is omitted.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/1`, `export/2`, `force_flush/1`, `shutdown/1` | **SDK** (Console implementation) |

  ## References

  - OTel Logs SDK Stdout: `opentelemetry-specification/specification/logs/sdk_exporters/stdout.md`
  - Parent behaviour: `Otel.SDK.Logs.LogRecordExporter`
  """

  @behaviour Otel.SDK.Logs.LogRecordExporter

  @impl true
  @spec init(config :: term()) :: {:ok, Otel.SDK.Logs.LogRecordExporter.state()}
  def init(config), do: {:ok, config}

  @impl true
  @spec export(
          log_records :: [Otel.SDK.Logs.LogRecord.t()],
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

  @spec format_log_record(record :: Otel.SDK.Logs.LogRecord.t()) :: String.t()
  defp format_log_record(record) do
    severity = format_severity(record)
    scope = format_scope(record)
    trace = format_trace(record)
    body = inspect(record.body)
    attrs = inspect(record.attributes)

    "[otel] #{severity} #{scope}#{trace}body=#{body} attributes=#{attrs}"
  end

  @spec format_severity(record :: Otel.SDK.Logs.LogRecord.t()) :: String.t()
  defp format_severity(%{severity_text: "", severity_number: 0}), do: "UNSPECIFIED"
  defp format_severity(%{severity_text: "", severity_number: n}), do: "severity=#{n}"
  defp format_severity(%{severity_text: text}), do: text

  @spec format_scope(record :: Otel.SDK.Logs.LogRecord.t()) :: String.t()
  defp format_scope(%{scope: %{name: ""}}), do: ""
  defp format_scope(%{scope: %{name: name}}), do: "scope=#{name} "

  @spec format_trace(record :: Otel.SDK.Logs.LogRecord.t()) :: String.t()
  defp format_trace(%{trace_id: trace_id, span_id: span_id}) do
    if Otel.API.Trace.TraceId.valid?(trace_id) and Otel.API.Trace.SpanId.valid?(span_id) do
      "trace=#{Otel.API.Trace.TraceId.to_hex(trace_id)} span=#{Otel.API.Trace.SpanId.to_hex(span_id)} "
    else
      ""
    end
  end
end
