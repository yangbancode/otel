defmodule Otel.Logs.LogRecordExporter do
  @moduledoc """
  OTLP/HTTP exporter for log records. Implements the
  `LogRecordExporter` behaviour expected by
  `Otel.Logs.LogRecordProcessor` — `init/1`, `export/2`,
  `force_flush/1`, `shutdown/1`.

  Delegates the actual POST to `Otel.OTLP.HTTP` with signal
  path `/v1/logs`. See that module's moduledoc for the
  user-facing `:req_options` config surface (auth, TLS,
  timeouts, retry, etc.).

  `init/1` keeps no state — `Otel.OTLP.HTTP` reads
  `:req_options` from `Application.get_env/2` on every export,
  so test-time reconfiguration takes effect immediately.
  """

  @logs_path "/v1/logs"

  @type state :: %{}

  @spec init(config :: term()) :: {:ok, state()}
  def init(_config), do: {:ok, %{}}

  @spec export(
          log_records :: [Otel.Logs.LogRecord.t()],
          state :: state()
        ) :: :ok | :error
  def export([], _state), do: :ok

  def export(log_records, _state) do
    log_records
    |> Otel.OTLP.Encoder.encode_logs()
    |> Otel.OTLP.HTTP.post(@logs_path)
  end

  @spec force_flush(state :: state()) :: :ok
  def force_flush(_state), do: :ok

  @spec shutdown(state :: state()) :: :ok
  def shutdown(_state), do: :ok
end
