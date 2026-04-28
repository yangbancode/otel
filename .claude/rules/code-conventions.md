## Code Conventions

### No alias

Do not use `alias`. Always use full module names.

```elixir
# Bad
alias Otel.API.Trace.SpanContext
SpanContext.new(...)

# Good
Otel.API.Trace.SpanContext.new(...)
```

### Typespec parameter names

Always include parameter names in `@spec` and `@callback`.

```elixir
# Bad
@spec new(non_neg_integer(), non_neg_integer()) :: t()

# Good
@spec new(trace_id :: non_neg_integer(), span_id :: non_neg_integer()) :: t()
```

```elixir
# Bad
@callback should_sample(Otel.API.Ctx.t(), non_neg_integer()) :: result()

# Good
@callback should_sample(ctx :: Otel.API.Ctx.t(), trace_id :: non_neg_integer()) :: result()
```

This applies to both public (`def`) and private (`defp`) functions.
Does not apply to `@type` — struct field names serve as documentation.

### Happy path only

Assume every function call succeeds. Do not write code that handles the
failure of a call — no `try/catch/rescue`, no `{:ok, _} | :error` tuples,
no `nil`-fallbacks on malformed external data, no silent filtering of
invalid entries.

A unified error-handling pass will be applied in the Finalization phase
(see `.claude/docs/architecture/error-handling.md`).

```elixir
# Bad — handles the failure case
case :httpc.request(...) do
  {:ok, response} -> :ok
  _ -> :error
end

# Good — asserts success, crashes on failure
{:ok, _response} = :httpc.request(...)
:ok
```

```elixir
# Bad — returns :error tuple on bad input
def from_hex(<<_::256>> = hex) do
  case Integer.parse(hex, 16) do
    {int, ""} -> {:ok, int}
    _ -> :error
  end
end

# Good — pattern-matches, crashes on bad input
def from_hex(<<_::256>> = hex) do
  {int, ""} = Integer.parse(hex, 16)
  int
end
```

**Not error handling** (keep these):

- Spec-mandated behavior (e.g. Noop dispatcher when no SDK is registered,
  `Propagator.Baggage.extract/3` returning unchanged context on missing
  header, `Propagator.extract/3` returning original context on malformed
  header per `context/api-propagators.md` L102).
- Lifecycle (`:shut_down` flag, supervisor trees).
- Flow control (batch processor queue overflow, load shedding).
- Exception-recording contract — `Trace.with_span/5` uses `catch` to
  record exceptions on spans and re-raise. This is API contract, not
  error handling.
- Pattern matching and guards at public-API entry points — these are
  type gates, not failure handling.
- BEAM return conventions — `{:ok, pid} = GenServer.start_link(...)`
  pattern matches the expected success shape.

### Layer independence (API ↛ SDK)

`Otel.API.*` modules define *"what interfaces exist"*; `Otel.SDK.*`
modules define *"how those interfaces are implemented"*. Dependency
flows strictly `SDK → API`, never the reverse.

When declaring a `@type` or `@callback` at the API layer, only
enumerate what the **OTel spec itself defines at that layer**. If
a spec section leaves behaviour details open (e.g. `trace/api.md`
L208-L210 *"currently no required parameters"* for
`Tracer.enabled?`), the API layer **must not** enumerate
speculative keys that would amount to assuming a particular SDK
implementation — even if a pattern from another behaviour
(`Logs.Logger`, `Metrics.Instrument`) suggests candidate keys.

In those cases the API type stays open (`keyword()`, `term()`,
etc.), and each SDK implementation may document its own accepted
keys in its own module typedoc.

```elixir
# API layer — spec defines no keys for Trace's Enabled API
@type enabled_opts :: keyword()

# SDK layer — free to document its own accepted keys
@typedoc "Keys recognised by MyRateLimitingTracer"
@type enabled_opt :: {:rate_override, non_neg_integer()}
```

Contrast with `Logs.Logger.enabled_opt` and
`Metrics.Instrument.enabled_opt`, where the spec **does** define
keys at the API level — enumeration is appropriate there because
it mirrors a spec contract, not an SDK assumption.
