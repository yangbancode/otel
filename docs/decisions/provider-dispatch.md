# Provider Dispatch

## Question

How does the API layer find and invoke the registered SDK Provider when
`Otel.API.<Signal>.<Signal>Provider.get_<signal>/4` is called?

Previously the `fetch_or_default/4` helper ignored its arguments and
returned the Noop provider unconditionally, so instrumentation that went
through the API layer never reached the SDK even when an SDK was
installed.

## Decision

### Registration

The SDK Provider's `init/1` callback stores a reference to itself in the
API layer's `persistent_term` key:

```elixir
Otel.API.Trace.TracerProvider.set_provider(self_ref())
```

`self_ref/0` returns the registered process name when the GenServer is
registered (typical for app-supervised providers that start with
`name: __MODULE__`), or the raw pid when it is unnamed (typical for
test-spawned providers). Both forms are valid targets for `GenServer.call/3`.

The API layer accepts both pid and atom:

```elixir
@spec set_provider(provider :: GenServer.server() | nil) :: :ok
def set_provider(provider) when is_atom(provider) or is_pid(provider) do
  :persistent_term.put(@provider_key, provider)
  :ok
end
```

### Dispatch

`fetch_or_default/4` consults `get_provider/0` and dispatches over
`GenServer.call/3`. A dead or unregistered target returns the Noop
provider so the API layer stays functional even if the SDK has gone
away:

```elixir
defp fetch_or_default(name, version, schema_url, attributes) do
  case get_provider() do
    nil ->
      @default_tracer

    provider ->
      if provider_alive?(provider) do
        GenServer.call(provider, {:get_tracer, name, version, schema_url, attributes})
      else
        @default_tracer
      end
  end
end

defp provider_alive?(pid) when is_pid(pid), do: Process.alive?(pid)
defp provider_alive?(name) when is_atom(name), do: Process.whereis(name) != nil
```

The `provider_alive?/1` check is not error handling — it is the
spec-mandated "API works without SDK" behaviour (see
`error-handling.md` L34). The same shape lives in
`Otel.API.Trace.Span`'s Noop dispatcher (`case get_span_module() do nil
-> :ok`).

### Caching

Once a provider returns a tracer/meter/logger, the API layer caches it
in `persistent_term` keyed by the full identity tuple:

```elixir
key = {@tracer_key_prefix, {name, version, schema_url, attributes}}
```

Subsequent `get_tracer/4` calls hit the cache and never re-dispatch.
`attributes` is part of the key since OTel spec v1.13.0 identifies
instrumentation scopes by `(name, version, schema_url, attributes)`.

### SDK-side contract

The SDK's `handle_call({:get_<signal>, name, version, schema_url,
attributes}, ...)` callback must accept the 5-tuple and build an
`Otel.API.InstrumentationScope` from it.

## Relationship to opentelemetry-erlang

Our dispatch matches the opentelemetry-erlang pattern:

- Tracer/Meter/Logger caches live in `persistent_term`.
- On a cache miss, the API layer calls into the SDK Provider via
  `gen_server:call`.
- No SDK installed → Noop.

One small difference: erlang catches `exit:{noproc, _}` with `try/catch`
where we use `provider_alive?/1` to stay compatible with the
happy-path-only code convention. The outcome is the same.

## Modules

- `apps/otel_api/lib/otel/api/trace/tracer_provider.ex`
- `apps/otel_api/lib/otel/api/metrics/meter_provider.ex`
- `apps/otel_api/lib/otel/api/logs/logger_provider.ex`
- `apps/otel_sdk/lib/otel/sdk/trace/tracer_provider.ex`
- `apps/otel_sdk/lib/otel/sdk/metrics/meter_provider.ex`
- `apps/otel_sdk/lib/otel/sdk/logs/logger_provider.ex`

## Compliance

- [Trace API](../compliance.md) — `# Trace API` TracerProvider:
  "MUST NOT require users to repeatedly obtain a Tracer with the same
  identity to pick up configuration changes" (L146).
- [Metrics API](../compliance.md) — `# Metrics API` MeterProvider:
  equivalent.
- [Logs API](../compliance.md) — `# Logs API` LoggerProvider:
  equivalent.
- Spec v1.13.0 identity of `(name, version, schema_url, attributes)`:
  relevant lines in each signal's compliance section.
