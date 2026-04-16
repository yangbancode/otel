defmodule Otel.SDK.Logs.LogRecordProcessor do
  @moduledoc """
  Behaviour for log record processors.

  Log record processors receive emitted log records and are
  responsible for passing them to exporters. Called synchronously
  from the Logger — implementations SHOULD NOT block or throw.

  Processors receive a ReadWriteLogRecord (a mutable map) on
  `on_emit`. Mutations made by one processor MUST be visible
  to the next registered processor in the chain.
  """

  @type config :: term()

  @doc """
  Called when a log record is emitted. SHOULD NOT block or throw.

  The `log_record` is a ReadWriteLogRecord — processors MAY modify
  fields (timestamp, severity, body, attributes, trace context, etc.).
  """
  @callback on_emit(log_record :: map(), config :: config()) :: :ok

  @doc """
  Returns whether the processor is interested in log records
  matching the given parameters.

  Modifications to parameters inside Enabled MUST NOT be
  propagated to the caller.
  """
  @callback enabled?(opts :: keyword(), config :: config()) :: boolean()

  @doc """
  Shuts down the processor. MUST include the effects of force_flush.
  """
  @callback shutdown(config :: config()) :: :ok | {:error, term()}

  @doc """
  Forces the processor to export all pending log records immediately.
  """
  @callback force_flush(config :: config()) :: :ok | {:error, term()}
end
