# Trace

## Quick start

```elixir
# mix.exs
{:otel, "~> 0.1"}
```

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app"}
tracer = Otel.API.Trace.TracerProvider.get_tracer(scope)

Otel.API.Trace.with_span(tracer, "checkout", fn _span_ctx ->
  process_order()
end)
```

The SDK ships traces to `http://localhost:4318/v1/traces` by default.
See [Configuration](configuration.md) to change endpoint or limits.

## Get a tracer

`InstrumentationScope` identifies *which library or module* produced
the telemetry — pick a stable `name` per scope (your OTP app or
module).

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
tracer = Otel.API.Trace.TracerProvider.get_tracer(scope)
```

## `with_span/4` — automatic lifecycle

The recommended form. Starts the span, makes it the current span for
the block, ends it on exit, and records any exception that escapes.

```elixir
Otel.API.Trace.with_span(tracer, "checkout", fn span_ctx ->
  process_order()
end)
```

With options:

```elixir
Otel.API.Trace.with_span(
  tracer,
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
span_ctx = Otel.API.Trace.start_span(tracer, "checkout", kind: :server)
# … do work, possibly across processes / messages …
Otel.API.Trace.Span.end_span(span_ctx)
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
Otel.API.Trace.with_span(tracer, "parent", fn _ ->
  ctx = Otel.API.Ctx.current()

  Task.async(fn ->
    Otel.API.Ctx.attach(ctx)
    Otel.API.Trace.with_span(tracer, "child", fn _ -> :work end)
  end)
end)
```

## Across services (HTTP / RPC)

Inject the active context into outgoing request headers; extract on the
server side. Default propagators are W3C TraceContext and W3C Baggage.

### Outbound (client)

```elixir
ctx = Otel.API.Ctx.current()
headers = Otel.API.Propagator.TextMap.inject(ctx, %{})
# => %{"traceparent" => "00-...-...", "tracestate" => "..."}

HTTPClient.post("https://api.example.com/orders", body, headers)
```

### Inbound (server)

```elixir
ctx = Otel.API.Propagator.TextMap.extract(Otel.API.Ctx.new(), conn.req_headers)
Otel.API.Ctx.attach(ctx)

Otel.API.Trace.with_span(tracer, "POST /orders", [kind: :server], fn _ ->
  handle_request()
end)
```

## Baggage

Baggage propagates name-value pairs alongside the span context —
visible to downstream services but not auto-attached as span
attributes.

```elixir
ctx =
  Otel.API.Ctx.current()
  |> Otel.API.Baggage.set_value("tenant.id", "acme")
  |> Otel.API.Baggage.set_value("feature.flag", "fast-checkout")

Otel.API.Ctx.attach(ctx)
```

Reading on the receiving side:

```elixir
ctx = Otel.API.Propagator.TextMap.extract(Otel.API.Ctx.new(), headers)
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

Defaults: 128 attributes / events / links per span, no string-length
truncation. Override per-pillar:

```elixir
config :otel,
  trace: [
    span_limits: %{
      attribute_count_limit: 256,
      attribute_value_length_limit: 1024,
      event_count_limit: 256,
      link_count_limit: 256
    }
  ]
```

See [Configuration](configuration.md) §"Trace pillar" for environment
variables and per-event / per-link limits.
