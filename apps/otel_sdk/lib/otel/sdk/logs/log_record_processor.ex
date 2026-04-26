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
              log_record :: Otel.SDK.Logs.LogRecord.t(),
              ctx :: Otel.API.Ctx.t(),
              config :: config()
            ) :: :ok

  @doc """
  Returns whether the processor is interested in log records
  matching the given parameters (spec L418-L455).

  Spec L420 — *"Enabled is an operation that a LogRecordProcessor
  MAY implement"*. Marked optional via `@optional_callbacks`
  below; the SDK Logger guards each delegation with
  `function_exported?/3` so processors that omit `enabled?/3`
  pass through transparently.

  Modifications to parameters inside `enabled?/3` MUST NOT be
  propagated to the caller (spec L439-L440).

  - `opts` — `Otel.API.Logs.Logger.enabled_opts/0`, the
    spec-defined keyword list with `:ctx`, `:severity_number`,
    `:event_name` (`logs/api.md` L137-L142).
  - `scope` — the Instrumentation Scope associated with the
    Logger (spec L427-L428). Supplied by the SDK Logger when
    delegating; the API caller never sees scope directly.
  """
  @callback enabled?(
              opts :: Otel.API.Logs.Logger.enabled_opts(),
              scope :: Otel.API.InstrumentationScope.t(),
              config :: config()
            ) :: boolean()

  @optional_callbacks enabled?: 3

  @doc """
  Shuts down the processor (spec L457-L474). MUST include the
  effects of `force_flush/2` (spec L469).

  `timeout` is the upper bound the processor SHOULD honor for
  the whole shutdown sequence (spec L471-L474). When a timeout
  is specified, spec L487-L491 says the processor MUST
  prioritize honoring it over finishing all calls, and L466-L467
  asks the processor to let the caller know whether the call
  succeeded, failed, or timed out — `{:error, :timeout}` is the
  conventional signal for the third case. Implementations
  propagate this to the underlying `:gen_statem.call/3` /
  `:gen_statem.stop/3` and may translate OTP's `:exit, :timeout`
  / `{:timeout, _}` into `{:error, :timeout}`.
  """
  @callback shutdown(config :: config(), timeout :: timeout()) :: :ok | {:error, term()}

  @doc """
  Forces the processor to export all pending log records
  immediately (spec L476-L503).

  Same `timeout` contract as `shutdown/2`: spec L487-L491 MUST
  prioritize honoring the timeout, and L492-L493 asks the
  processor to let the caller know whether the call succeeded,
  failed, or timed out. `{:error, :timeout}` is the
  conventional signal for the third case.
  """
  @callback force_flush(config :: config(), timeout :: timeout()) :: :ok | {:error, term()}
end
