# Trace

## Quick start

```elixir
# mix.exs
{:otel, "~> 0.1"}
```

```elixir
Otel.Trace.with_span("checkout", fn _span_ctx ->
  process_order()
end)
```

The SDK ships traces to `http://localhost:4318/v1/traces` by default.
See [Configuration](configuration.md) to change endpoint or limits.

Minikube hardcodes the instrumentation scope to the SDK identity
(`name: "otel"`, `version: <SDK vsn>`) — there is no Tracer
handle to obtain via `get_tracer/0` first; call `Otel.Trace`
functions directly.

## `with_span/4` — automatic lifecycle

The recommended form. Starts the span, makes it the current span for
the block, ends it on exit, and records any exception that escapes.

```elixir
Otel.Trace.with_span("checkout", fn span_ctx ->
  process_order()
end)
```

With options:

```elixir
Otel.Trace.with_span(
  "checkout",
  [
    kind: :server,
    attributes: %{"user.id" => 42}
  ],
  fn span_ctx ->
    process_order()
  end
)
```

## Manual lifecycle

For spans that don't fit a single function scope.

```elixir
span_ctx = Otel.Trace.start_span("checkout", kind: :server)
# … do work, possibly across processes / messages …
Otel.Trace.Span.end_span(span_ctx)
```

## Attributes

```elixir
Otel.API.Trace.Span.set_attribute(span_ctx, "http.method", "GET")

Otel.API.Trace.Span.set_attributes(span_ctx, %{
  "http.status_code" => 200,
  "http.url" => "/orders/42"
})
```

## Events

```elixir
event = Otel.API.Trace.Event.new("cart.validated", %{"item.count" => 3})
Otel.API.Trace.Span.add_event(span_ctx, event)
```

## Links

```elixir
linked_ctx = Otel.API.Trace.SpanContext.new(trace_id, span_id, 1)
link = %Otel.API.Trace.Link{context: linked_ctx, attributes: %{"reason" => "fork"}}
Otel.API.Trace.Span.add_link(span_ctx, link)
```

## Status

```elixir
Otel.API.Trace.Span.set_status(span_ctx, Otel.API.Trace.Status.new(:ok))

Otel.API.Trace.Span.set_status(
  span_ctx,
  Otel.API.Trace.Status.new(:error, "payment declined")
)
```

`with_span/4` automatically sets `:error` status and records any
exception that escapes the function — manual `set_status(:error)` is
only needed when the operation failed without raising.

## Exceptions

```elixir
try do
  process_order()
rescue
  exception ->
    Otel.API.Trace.Span.record_exception(span_ctx, exception, __STACKTRACE__)
    reraise exception, __STACKTRACE__
end
```

`with_span/4` does this automatically; reach for `record_exception/3,4`
only inside manual lifecycle code or when recording without re-raising.

## Update name

```elixir
Otel.API.Trace.Span.update_name(span_ctx, "checkout (premium tier)")
```

## Span kinds

| Kind | Use for |
|---|---|
| `:internal` (default) | in-process work |
| `:server` | inbound RPC / HTTP server |
| `:client` | outbound RPC / HTTP client |
| `:producer` | message produced (Kafka, RabbitMQ, …) |
| `:consumer` | message consumed |

Pass via `kind:` option on `start_span` / `with_span`.

## Across processes (`Task`, `GenServer.cast`, …)

BEAM processes don't inherit the parent's process dictionary, so the
current span context doesn't follow `Task.async/spawn` automatically.
Capture and re-attach explicitly:

```elixir
Otel.Trace.with_span("parent", fn _ ->
  ctx = Otel.Ctx.current()

  Task.async(fn ->
    Otel.Ctx.attach(ctx)
    Otel.Trace.with_span("child", fn _ -> :work end)
  end)
end)
```

## Across services (HTTP / RPC)

Inject the active context into outgoing request headers; extract on the
server side. The SDK is hardcoded to W3C TraceContext + W3C Baggage —
no other propagators (B3, Jaeger, etc.) are shipped.

### Outbound (client)

```elixir
ctx = Otel.Ctx.current()
headers = Otel.API.Propagator.TextMap.inject(ctx, %{})
# => %{"traceparent" => "00-...-...", "tracestate" => "..."}

HTTPClient.post("https://api.example.com/orders", body, headers)
```

### Inbound (server)

```elixir
ctx = Otel.API.Propagator.TextMap.extract(Otel.Ctx.new(), conn.req_headers)
Otel.Ctx.attach(ctx)

Otel.Trace.with_span("POST /orders", [kind: :server], fn _ ->
  handle_request()
end)
```

## Baggage

Baggage propagates name-value pairs alongside the span context —
visible to downstream services but not auto-attached as span
attributes.

```elixir
ctx =
  Otel.Ctx.current()
  |> Otel.API.Baggage.set_value("tenant.id", "acme")
  |> Otel.API.Baggage.set_value("feature.flag", "fast-checkout")

Otel.Ctx.attach(ctx)
```

Reading on the receiving side:

```elixir
ctx = Otel.API.Propagator.TextMap.extract(Otel.Ctx.new(), headers)
{value, _metadata} = Otel.API.Baggage.get_value(Otel.API.Baggage.current(ctx), "tenant.id")
# value => "acme"
```

## Sampling

Hardcoded `parentbased_always_on` — root spans always sample, children
inherit the parent's decision (sampled flag set → record; not set →
drop). Not configurable.

For finer control (head ratio sampling, custom samplers), use
[`opentelemetry-erlang`](https://github.com/open-telemetry/opentelemetry-erlang).
For tail sampling (latency / error / rate), configure your collector's
`tail_sampling_processor`.

## Limits

Hardcoded to spec defaults: 128 attributes / events / links per span,
no string-length truncation. Not user-configurable — see
[Configuration](configuration.md) §"What's *not* user-configurable".
