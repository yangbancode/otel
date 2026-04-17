# Using Semantic Convention Constants with Spans

Recipes for emitting standardized attributes on OTel spans. Each example assumes you already have a `span` reference from `Otel.API.Trace.with_span/3` or equivalent.

> ### Companion package required {: .info}
>
> These recipes use `Otel.API.Trace.Span.set_attribute/3` from the `otel_api` package. Add it to your dependencies if you haven't already.

## Set a single attribute

Look up the standardized key by calling the matching attribute function — never type the string literal yourself:

```elixir
import Otel.SemConv.Attributes.HTTP

Otel.API.Trace.Span.set_attribute(span, http_request_method(), "POST")
```

Or use the fully qualified call when you don't want to import:

```elixir
Otel.API.Trace.Span.set_attribute(
  span,
  Otel.SemConv.Attributes.HTTP.http_request_method(),
  "POST"
)
```

## Set many attributes at once

Build a map keyed by the constants and pass it to `set_attributes/2`:

```elixir
import Otel.SemConv.Attributes.HTTP
import Otel.SemConv.Attributes.URL
import Otel.SemConv.Attributes.Server

Otel.API.Trace.Span.set_attributes(span, %{
  http_request_method() => "POST",
  url_path() => "/api/orders",
  url_scheme() => "https",
  server_address() => "api.example.com",
  server_port() => 443
})
```

## Use enum attribute values

Enum attributes (HTTP request method, DB system, etc.) have a `_values()` helper that returns a map from member atom to canonical string. Use the atom keys as type-checked Elixir-side handles:

```elixir
import Otel.SemConv.Attributes.HTTP

methods = http_request_method_values()
# => %{:connect => "CONNECT", :delete => "DELETE", :get => "GET", ...}

Otel.API.Trace.Span.set_attribute(span, http_request_method(), methods[:post])
# Sets http.request.method = "POST"
```

When the incoming method isn't in the enum (e.g. a custom verb), pass the string directly — the spec allows extension:

```elixir
Otel.API.Trace.Span.set_attribute(span, http_request_method(), "QUERY")
```

## HTTP server span — full example

```elixir
defmodule MyApp.HTTPServer do
  import Otel.SemConv.Attributes.HTTP
  import Otel.SemConv.Attributes.URL
  import Otel.SemConv.Attributes.Server
  import Otel.SemConv.Attributes.Network

  def handle(conn) do
    Otel.API.Trace.with_span(tracer(), "HTTP #{conn.method}", fn _ctx ->
      span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())

      Otel.API.Trace.Span.set_attributes(span, %{
        http_request_method() => conn.method,
        url_path() => conn.request_path,
        url_scheme() => to_string(conn.scheme),
        server_address() => conn.host,
        server_port() => conn.port,
        network_protocol_version() => "1.1"
      })

      response = process(conn)

      Otel.API.Trace.Span.set_attribute(
        span,
        http_response_status_code(),
        response.status
      )

      response
    end)
  end
end
```

## Database query span

```elixir
import Otel.SemConv.Attributes.DB

Otel.API.Trace.with_span(tracer(), "SELECT users", fn _ctx ->
  span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())

  Otel.API.Trace.Span.set_attributes(span, %{
    db_system_name() => "postgresql",
    db_query_text() => "SELECT id, email FROM users WHERE id = $1",
    db_namespace() => "myapp_prod"
  })

  Repo.query!(...)
end)
```

## Error attributes

When a span captures an exception, use the standard error type key:

```elixir
import Otel.SemConv.Attributes.Error

try do
  process(payload)
rescue
  exception ->
    Otel.API.Trace.Span.set_attribute(
      span,
      error_type(),
      inspect(exception.__struct__)
    )

    reraise exception, __STACKTRACE__
end
```

> ### Tip {: .tip}
>
> `Otel.API.Trace.with_span/3` already records exceptions and re-raises them. The recipe above is for the case where you handle the exception yourself but still want it on the span.

## Why bother with constants?

Compare the two:

```elixir
# Risky — typo is silent
Span.set_attribute(span, "http.respnose.status_code", 500)

# Safe — typo is a compile error
Span.set_attribute(span, http_response_status_code(), 500)
```

The constants give you the OTel spec's canonical key with no chance of drift, plus IDE autocompletion to discover related attributes in the same group.
