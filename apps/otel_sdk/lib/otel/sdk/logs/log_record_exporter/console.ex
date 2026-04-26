defmodule Otel.SDK.Logs.LogRecordExporter.Console do
  @moduledoc """
  Standard-output `LogRecordExporter` for debugging
  (`logs/sdk_exporters/stdout.md`).

  Outputs each `Otel.SDK.Logs.LogRecord` to stdout in a
  human-readable single-line format. Spec L16-L18 — *"This
  exporter is intended for debugging and learning purposes.
  It is not recommended for production use. The output format
  is not standardized and can change at any time."*

  Spec L29-L34 — recommended pairing is
  `Otel.SDK.Logs.LogRecordProcessor.Simple`. The spec SHOULD
  is conditional on the SDK providing an auto-configuration
  mechanism (e.g. `OTEL_LOGS_EXPORTER`); this SDK does not
  currently, so the pairing is informational rather than
  mandated.

  ## Output format

  Single line per record, prefixed with `[otel]`:

      [otel] <severity> [scope=<name> ]trace=<hex> span=<hex> body=<inspect> attributes=<inspect>

  - **severity** — combined display per `data-model.md`
    §Displaying Severity L365-L372: short name derived from
    `severity_number` (e.g. `INFO`), with `severity_text`
    appended in parentheses when both are present
    (`INFO (info)`). Falls back to `severity_text` alone when
    `severity_number == 0`, the short name alone when
    `severity_text` is empty, and `UNSPECIFIED` when both are
    the proto3 zero value. The `UNSPECIFIED` choice follows
    `data-model.md` L298-L302 option 1 (distinct display of
    missing severity) over option 2 (interpret as INFO) — a
    debug exporter benefits from preserving the source signal
    rather than fabricating a level.
  - **scope** — emitted only when `scope.name` is non-empty.
  - **trace context** — always rendered as 32-hex `trace_id`
    and 16-hex `span_id`. When no Context is active,
    `Otel.SDK.Logs.LogRecord` defaults both to the all-zeros
    invalid sentinel; the field is still emitted so the
    absence is visible at a glance, matching
    `Otel.SDK.Trace.SpanExporter.Console`.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/1`, `export/2`, `force_flush/1`, `shutdown/1` | **SDK** (Console implementation) |

  ## References

  - OTel Logs SDK Stdout: `opentelemetry-specification/specification/logs/sdk_exporters/stdout.md`
  - SeverityNumber short-name table: `opentelemetry-specification/specification/logs/data-model.md` §Displaying Severity L334-L372
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
  defp format_severity(%{severity_text: text, severity_number: 0}), do: text
  defp format_severity(%{severity_text: "", severity_number: n}), do: short_name(n)

  defp format_severity(%{severity_text: text, severity_number: n}) do
    "#{short_name(n)} (#{text})"
  end

  # Spec `data-model.md` §Displaying Severity L334-L363 short-name
  # table. Kept private — Console is currently the only consumer. If
  # another exporter needs the same lookup later, promote to
  # `Otel.API.Logs.severity_short_name/1`.
  @spec short_name(n :: 1..24) :: String.t()
  defp short_name(1), do: "TRACE"
  defp short_name(2), do: "TRACE2"
  defp short_name(3), do: "TRACE3"
  defp short_name(4), do: "TRACE4"
  defp short_name(5), do: "DEBUG"
  defp short_name(6), do: "DEBUG2"
  defp short_name(7), do: "DEBUG3"
  defp short_name(8), do: "DEBUG4"
  defp short_name(9), do: "INFO"
  defp short_name(10), do: "INFO2"
  defp short_name(11), do: "INFO3"
  defp short_name(12), do: "INFO4"
  defp short_name(13), do: "WARN"
  defp short_name(14), do: "WARN2"
  defp short_name(15), do: "WARN3"
  defp short_name(16), do: "WARN4"
  defp short_name(17), do: "ERROR"
  defp short_name(18), do: "ERROR2"
  defp short_name(19), do: "ERROR3"
  defp short_name(20), do: "ERROR4"
  defp short_name(21), do: "FATAL"
  defp short_name(22), do: "FATAL2"
  defp short_name(23), do: "FATAL3"
  defp short_name(24), do: "FATAL4"

  @spec format_scope(record :: Otel.SDK.Logs.LogRecord.t()) :: String.t()
  defp format_scope(%{scope: %{name: ""}}), do: ""
  defp format_scope(%{scope: %{name: name}}), do: "scope=#{name} "

  @spec format_trace(record :: Otel.SDK.Logs.LogRecord.t()) :: String.t()
  defp format_trace(%{trace_id: trace_id, span_id: span_id}) do
    "trace=#{Otel.API.Trace.TraceId.to_hex(trace_id)} span=#{Otel.API.Trace.SpanId.to_hex(span_id)} "
  end
end
