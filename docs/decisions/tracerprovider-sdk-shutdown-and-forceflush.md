# TracerProvider SDK: Shutdown & ForceFlush

## Question

How to implement Shutdown and ForceFlush cascading to all processors on BEAM? How to handle timeouts with GenServer.call?

## Decision

### Shutdown

`shutdown/1` sends a GenServer call that:
1. Invokes shutdown on all registered processors
2. Marks the provider as shut down
3. Returns `:ok | {:error, reason}`

After shutdown, `get_tracer` returns the noop tracer. Subsequent shutdown calls return `{:error, :already_shut_down}`.

Timeout is handled via GenServer.call timeout (default 5000ms).

### ForceFlush

`force_flush/1` sends a GenServer call that invokes `force_flush` on all registered processors, collecting results. Returns `:ok | {:error, reasons}`.

### Processor Interface

Both shutdown and force_flush delegate to processor modules. The SpanProcessor behaviour (defined in a later decision) will require:
- `shutdown(config) :: :ok | {:error, term()}`
- `force_flush(config) :: :ok | {:error, term()}`

### Module

Functions added to `Otel.SDK.Trace.TracerProvider`.

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * TracerProvider — Shutdown — L161, L163, L165, L168, L173
  * TracerProvider — ForceFlush — L179, L182, L187
