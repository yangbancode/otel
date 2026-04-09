# TracerProvider SDK: Shutdown & ForceFlush

## Question

How to implement Shutdown and ForceFlush cascading to all processors on BEAM? How to handle timeouts with GenServer.call?

## Decision

TBD

## Compliance

- `compliance/trace-sdk.md` — Shutdown + ForceFlush (8 items: shutdown once, no-op after shutdown, success/failure/timeout, cascade to processors)
