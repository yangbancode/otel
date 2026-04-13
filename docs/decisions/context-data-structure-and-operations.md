# Context

## Question

How to implement OTel Context on BEAM? What data structure, how to store per-process, how to pass across processes?

## Decision

### Data Structure

Context is a plain map. Same as opentelemetry-erlang.

### Process-Local Storage

Current context is stored in the process dictionary under a private key. `attach/1` sets it, `get_current/0` reads it, `detach/1` restores a previous context.

### Cross-Process Passing

No automatic propagation. BEAM processes share nothing. Users pass context explicitly:

```elixir
ctx = Otel.API.Ctx.get_current()
Task.async(fn ->
  Otel.API.Ctx.attach(ctx)
  # ...
end)
```

### Module: `Otel.API.Ctx`

Location: `apps/otel_api/lib/otel/api/ctx.ex`

Follows the same API shape as `otel_ctx` in opentelemetry-erlang:

| Function | Description |
|---|---|
| `create_key/1` | Creates an opaque context key via `make_ref/0` |
| `new/0` | Returns an empty context (`%{}`) |
| `get_value/1,2,3` | Get value by key (implicit or explicit context) |
| `set_value/2,3` | Set value by key (implicit or explicit context) |
| `remove/1,2` | Remove key (implicit or explicit context) |
| `clear/0,1` | Clear all keys (implicit or explicit context) |
| `get_current/0` | Get current process context |
| `attach/1` | Set current process context, return token |
| `detach/1` | Restore context from token |

### Note on CreateKey and BEAM

The spec's `CreateKey` exists to prevent key collisions when multiple libraries share a single Context object (common in Java, Python, Go). On BEAM this problem does not exist: processes are isolated, module attributes are private, and OTel is the sole Context user. Erlang's opentelemetry-erlang does not implement `CreateKey` for this reason. We implement it for spec compliance, but it is effectively ceremony on BEAM.

## Compliance

- [Context](../compliance.md)
  * Overview — L37
  * Create a Key — L65, L65, L67
  * Get Value — L74, L79
  * Set Value — L86, L92
  * Optional Global Operations — L98, L103, L109, L113, L133
