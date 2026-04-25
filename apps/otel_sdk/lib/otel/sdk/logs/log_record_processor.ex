defmodule Otel.SDK.Logs.LogRecordProcessor do
  @moduledoc """
  Behaviour for log record processors
  (`logs/sdk.md` §LogRecordProcessor L350-L503).

  Log record processors receive emitted log records and are
  responsible for passing them to exporters. Called synchronously
  from the Logger — implementations SHOULD NOT block or throw
  (spec L396-L397).

  Processors receive a ReadWriteLogRecord (a mutable map) on
  `on_emit/3` along with the resolved Context (spec L401-L404).
  Mutations made by one processor MUST be visible to the next
  registered processor in the chain (spec L408-L409).
  """

  @type config :: term()

  @doc """
  Called when a log record is emitted (spec L393-L416).

  SHOULD NOT block or throw. The `log_record` is a
  ReadWriteLogRecord — processors MAY modify fields
  (timestamp, severity, body, attributes, trace context, etc.).
  `ctx` is the resolved Context (the explicitly passed Context
  or the current Context at emit time).
  """
  @callback on_emit(
              log_record :: map(),
              ctx :: Otel.API.Ctx.t(),
              config :: config()
            ) :: :ok

  @doc """
  Returns whether the processor is interested in log records
  matching the given parameters (spec L418-L455).

  Spec L420 — *"Enabled is an operation that a LogRecordProcessor
  **MAY** implement"*. Marked optional via `@optional_callbacks`
  below; the SDK Logger guards each delegation with
  `function_exported?/3` so processors that omit `enabled?/3`
  pass through transparently.

  Modifications to parameters inside `enabled?/3` MUST NOT be
  propagated to the caller (spec L439-L440).

  - `opts` — caller-supplied keyword list with `:ctx`,
    `:severity_number`, `:event_name` per
    `Otel.API.Logs.Logger.enabled_opt/0`.
  - `scope` — the Instrumentation Scope associated with the
    Logger (spec L427-L428). Supplied by the SDK Logger when
    delegating; the API caller never sees scope directly.
  """
  @callback enabled?(
              opts :: keyword(),
              scope :: Otel.API.InstrumentationScope.t(),
              config :: config()
            ) :: boolean()

  @optional_callbacks enabled?: 3

  @doc """
  Shuts down the processor (spec L457-L474). MUST include the
  effects of `force_flush/1` (spec L469).
  """
  @callback shutdown(config :: config()) :: :ok | {:error, term()}

  @doc """
  Forces the processor to export all pending log records
  immediately (spec L476-L503).
  """
  @callback force_flush(config :: config()) :: :ok | {:error, term()}
end
