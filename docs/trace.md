# Trace

## Get a tracer

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
tracer = Otel.API.Trace.TracerProvider.get_tracer(scope)
```

## `with_span/4` — automatic lifecycle

The recommended form. `with_span/4` starts the span, makes it the current
span for the block, ends it on exit, and records any exception that
escapes.

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

For cases where the span doesn't fit a single function scope.

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
