# Provider Dispatch

## Question

How does the API layer find and invoke the registered SDK Provider when
`Otel.API.<Signal>.<Signal>Provider.get_<signal>/4` is called, without
leaking SDK implementation details (GenServer, registry, etc.) into the
API layer's contract?

## Decision

### `{dispatcher_module, state}` — the API's Provider abstraction

The API layer models a Provider the same way it already models Tracers,
Meters, and Loggers — as a `{module, state}` tuple backed by a
behaviour:

```elixir
@type t :: {module(), term()}

@callback get_tracer(
            state :: term(),
            instrumentation_scope :: Otel.API.InstrumentationScope.t()
          ) :: Otel.API.Trace.Tracer.t()
```

- `module` is the dispatcher — it implements the Provider behaviour
  and the API calls into its `get_<signal>/5` callback blindly.
- `state` is opaque to the API. It's whatever the dispatcher needs to
  do its work (a pid, a registered name, a config, a reference, …).

The type stays `{module(), term()}` because Elixir has no way to
express "a module that implements behaviour X" at the type level. The
behaviour contract lives at the `@callback` layer and is checked by
the compiler via `@behaviour` and `@impl true` on the implementing
module.

The API never does `GenServer.call/3`. The API never checks liveness.
The API doesn't know or care whether the SDK uses GenServer at all.
Everything about dispatch lives inside the SDK's dispatcher module.

### Registration

The SDK declares the behaviour and builds the tuple in its `init/1`:

```elixir
defmodule Otel.SDK.Trace.TracerProvider do
  use GenServer
  @behaviour Otel.API.Trace.TracerProvider

  @impl Otel.API.Trace.TracerProvider
  def get_tracer(server, name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    # ...
  end

  def init(_user_config) do
    Otel.API.Trace.TracerProvider.set_provider({__MODULE__, self_ref()})
    {:ok, ...}
  end
end
```

`@behaviour` + `@impl true` give compile-time verification that the SDK
supplies the callback the API expects.

`self_ref/0` is the SDK's helper — it returns the registered name if the
GenServer started with `name: __MODULE__` (the supervised path), or the
raw pid if it was started without a name (the direct-test path). Both
are valid `GenServer.call/3` targets inside the SDK, but the API
doesn't see this.

API `set_provider/1` accepts only the `{module, state}` tuple:

```elixir
@spec set_provider(provider :: t()) :: :ok
def set_provider({_module, _state} = provider) do
  :persistent_term.put(@provider_key, provider)
  :ok
end
```

No `nil` clause — callers that need to clear the registration
(tests, re-initialization scenarios) use `:persistent_term.erase/1`
directly. Adding a `set_provider(nil)` path only to have tests
call it would widen the API surface without a lib consumer.

### Dispatch

`fetch_or_default/4` pattern-matches the tuple and delegates:

```elixir
defp fetch_or_default(name, version, schema_url, attributes) do
  case get_provider() do
    nil ->
      @default_tracer

    {module, state} ->
      module.get_tracer(state, name, version, schema_url, attributes)
  end
end
```

That's it. No `GenServer`, no `Process.alive?/1`, no `Process.whereis/1`.
If the dispatcher module decides it wants to call a GenServer, check
liveness, hit an ETS table, or do something entirely different, that's
its problem.

### Liveness — pushed into the SDK

The SDK's `get_<signal>/5` is responsible for handling the "I'm no
longer alive" case. Our SDK uses GenServer, so it does the liveness
check itself and falls back to the Noop tuple on a dead server:

```elixir
def get_tracer(server, name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
  if alive?(server) do
    GenServer.call(server, {:get_tracer, name, version, schema_url, attributes})
  else
    {Otel.API.Trace.Tracer.Noop, []}
  end
end

defp alive?(pid) when is_pid(pid), do: Process.alive?(pid)
defp alive?(name) when is_atom(name), do: Process.whereis(name) != nil
```

This keeps the spec's "API works without SDK" guarantee intact (a
stopped SDK hands back the Noop tuple rather than crashing) without
forcing the API to know how aliveness is defined for every possible
dispatcher.

### Caching

Once a dispatcher returns a tracer/meter/logger, the API caches it in
`persistent_term` keyed by the full identity tuple:

```elixir
key = {@tracer_key_prefix, {name, version, schema_url, attributes}}
```

Subsequent `get_tracer/4` calls hit the cache and never re-dispatch.
`attributes` is part of the key since OTel spec v1.13.0 identifies
instrumentation scopes by `(name, version, schema_url, attributes)`.

### SDK-side contract

The SDK's `handle_call({:get_<signal>, name, version, schema_url,
attributes}, ...)` callback accepts the 5-tuple and builds an
`Otel.API.InstrumentationScope` from it. That's an implementation
detail of the SDK dispatcher, not part of the API contract.

## Relationship to opentelemetry-erlang

The reference implementation also uses `persistent_term` for tracer
caching and routes cache misses through a process, but its API layer
calls `gen_server:call/2` directly and catches `exit:{noproc, _}` to
fall back to Noop. That bakes "the SDK is a `gen_server`" into the
API.

We chose a looser contract — the API speaks `{module, state}`, the SDK
owns dispatch — so a future SDK written as a pure module, a Registry
lookup, or anything else can plug in without touching the API.

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
- [error-handling.md L34](../../references/opentelemetry-specification/specification/error-handling.md)
  "API call sites will not crash on attempts to access methods and
  properties of null objects": satisfied by the SDK's liveness
  fallback to Noop.
