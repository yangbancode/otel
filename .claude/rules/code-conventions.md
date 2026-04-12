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

Write code for the success path only. Do not add `try/catch/rescue` for error handling.

Error handling will be applied as a single pass in the Finalization phase
(see `docs/decisions/error-handling.md`).

Exception: `Trace.with_span` uses `catch` for span lifecycle management
(recording exceptions on spans and re-raising) — this is not error handling.
