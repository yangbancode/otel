defmodule Otel.SDK.Logs.LogRecordExporter do
  @moduledoc """
  Behaviour for log record exporters.

  Exporters receive batches of log records and transmit them to a
  backend. Protocol-specific logic (encoding, transport) lives in
  the exporter implementation.

  Export MUST NOT be called concurrently for the same instance.
  The processor serializes export calls.
  """

  @type state :: term()

  @doc """
  Initializes the exporter. Returns `{:ok, state}` or `:ignore`.
  """
  @callback init(config :: term()) :: {:ok, state()} | :ignore

  @doc """
  Exports a batch of log records. MUST NOT block indefinitely.
  """
  @callback export(log_records :: [map()], state :: state()) :: :ok | :error

  @doc """
  Forces the exporter to flush any buffered data.
  """
  @callback force_flush(state :: state()) :: :ok

  @doc """
  Shuts down the exporter. After shutdown, export calls SHOULD
  return failure.
  """
  @callback shutdown(state :: state()) :: :ok
end
