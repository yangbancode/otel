defmodule Otel.SDK.Logs.LogRecordExporter do
  @moduledoc """
  Behaviour for log record exporters
  (`logs/sdk.md` §LogRecordExporter L549-L645 + §Concurrency
  requirements L647-L660).

  Exporters serialize batches of `Otel.SDK.Logs.LogRecord` to a
  protocol and transmit them to a backend. Spec L555-L557:
  *"The protocol exporter is expected to be primarily a simple
  telemetry data encoder and transmitter."*

  Spec L572-L573 — *"`Export` should not be called concurrently
  with other `Export` calls for the same exporter instance."*
  The SDK's `Otel.SDK.Logs.LogRecordProcessor.Simple` and
  `Otel.SDK.Logs.LogRecordProcessor.Batch` serialize export
  calls through a GenServer, so exporter implementations may
  assume single-threaded `export/2`.

  Spec L654-L660 — `force_flush/1` and `shutdown/1` MUST be
  safe to call concurrently with `export/2`.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/1` | **SDK** (SDK lifecycle) |
  | `export/2` | **SDK** (OTel API MUST) |
  | `force_flush/1` | **SDK** (OTel API MUST) |
  | `shutdown/1` | **SDK** (OTel API MUST) |

  ## Design notes

  Three deliberate divergences from
  `references/opentelemetry-erlang/apps/opentelemetry_experimental/src/otel_exporter_logs.erl`:

  1. **`force_flush/1` callback present** — erlang's
     `otel_exporter_logs.erl` exports only `init/1`, `export/3`,
     `shutdown/1`. Spec L564 lists ForceFlush in the MUST-support
     functions, so we add it here. Erlang has a spec gap; we
     follow spec.
  2. **Resource embedded in `LogRecord`** — erlang's
     `export(list(), otel_resource:t(), term())` passes Resource
     as a separate arg. Our `Otel.SDK.Logs.LogRecord` already
     carries `resource` per spec L283 (*"Resource information
     (implicitly) associated with the LogRecord"*), so passing
     it again would duplicate state. Both shapes satisfy the
     spec.
  3. **Binary `ExportResult`** — erlang returns
     `ok | success | failed_not_retryable | failed_retryable`.
     Spec L598-L608 defines `ExportResult` as binary
     Success/Failure with no retry-class signal, and spec
     L585-L590 makes retry the exporter's responsibility (the
     processor doesn't dispatch on result). We use `:ok | :error`
     to match spec semantics; richer retry classification stays
     internal to each exporter implementation.

  ## References

  - OTel Logs SDK: `opentelemetry-specification/specification/logs/sdk.md`
  - Erlang reference: `opentelemetry-erlang/apps/opentelemetry_experimental/src/otel_exporter_logs.erl`
  """

  @typedoc """
  Implementer-owned state returned by `init/1` and threaded
  through `export/2`, `force_flush/1`, `shutdown/1`. Opaque to
  the SDK — each exporter implementation defines its own shape
  (e.g. HTTP client config, file handles, batch buffers).
  """
  @type state :: term()

  @doc """
  **SDK** (SDK lifecycle) — Initializes the exporter from the
  caller-supplied config and returns the implementer-owned
  `state` to thread through subsequent calls. Returning
  `:ignore` causes the owning processor to drop log records
  silently (used when an exporter is configured but disabled).

  Not in the spec (lifecycle is language-specific); mirrors
  the erlang reference `init/1` callback shape.
  """
  @callback init(config :: term()) :: {:ok, state()} | :ignore

  @doc """
  **SDK** (OTel API MUST) — "Export" (`logs/sdk.md` L566-L612).

  Exports a batch of `Otel.SDK.Logs.LogRecord`. Spec L582-L583:
  *"`Export` MUST NOT block indefinitely, there MUST be a
  reasonable upper limit after which the call must time out
  with an error result (`Failure`)."*

  Spec L598-L608 defines the return as `ExportResult`:
  - `:ok` — Success (batch successfully exported)
  - `:error` — Failure (batch must be dropped, e.g. unserializable)

  Spec L585-L590 — concurrent requests and retry logic are the
  exporter's responsibility, not the processor's.

  Spec L637-L639 — after `shutdown/1`, subsequent `export/2`
  calls SHOULD return `:error`. Implementations that expose a
  shutdown state must enforce this themselves.
  """
  @callback export(log_records :: [Otel.SDK.Logs.LogRecord.t()], state :: state()) ::
              :ok | :error

  @doc """
  **SDK** (OTel API MUST) — "ForceFlush"
  (`logs/sdk.md` L614-L630).

  Hint to flush any buffered records as soon as possible.

  Spec L620-L621: *"`ForceFlush` SHOULD provide a way to let
  the caller know whether it succeeded, failed or timed out."*
  - `:ok` — flush completed
  - `{:error, reason}` — flush failed or timed out (`reason`
    is implementation-defined, e.g. `:timeout`)

  Spec L627-L630 — `ForceFlush` SHOULD complete or abort
  within some timeout; SDK authors MAY make the timeout
  configurable.
  """
  @callback force_flush(state :: state()) :: :ok | {:error, term()}

  @doc """
  **SDK** (OTel API MUST) — "Shutdown"
  (`logs/sdk.md` L632-L643).

  Cleans up exporter resources. Spec L637-L639: *"Shutdown
  SHOULD be called only once for each `LogRecordExporter`
  instance. After the call to `Shutdown` subsequent calls to
  `Export` are not allowed and SHOULD return a Failure result."*

  Spec L641-L643: *"`Shutdown` SHOULD NOT block indefinitely
  (e.g. if it attempts to flush the data and the destination
  is unavailable)."*
  - `:ok` — shutdown completed
  - `{:error, reason}` — shutdown failed or timed out
  """
  @callback shutdown(state :: state()) :: :ok | {:error, term()}
end
