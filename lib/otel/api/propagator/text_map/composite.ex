defmodule Otel.API.Propagator.TextMap.Composite do
  @moduledoc """
  Composite TextMap propagator (OTel
  `context/api-propagators.md` §Composite Propagator,
  L259-L305).

  Groups multiple TextMap propagators into a single entity:
  `inject/4` calls each inner propagator's inject in order on
  the same carrier; `extract/4` threads the context through
  each propagator so later ones see earlier extractions.

  ## Usage

  Obtain a composite via `new/1` and register it with
  `Otel.API.Propagator.TextMap.set_propagator/1`:

      [Otel.API.Propagator.TextMap.TraceContext,
       Otel.API.Propagator.TextMap.Baggage]
      |> Otel.API.Propagator.TextMap.Composite.new()
      |> Otel.API.Propagator.TextMap.set_propagator()

  Dispatch goes through the facade:
  `Otel.API.Propagator.TextMap.inject/2,3` and `extract/2,3` →
  `inject_with`/`extract_with` → `inject/4`/`extract/4` here.

  ## Relationship to the TextMapPropagator behaviour

  Composite is **not itself** an `Otel.API.Propagator.TextMap`
  implementation — the behaviour's callbacks are 3-arity
  (`inject(ctx, carrier, setter)`), matching single propagators
  like `TraceContext` or `Baggage`. Composite is a **configured
  wrapper** that requires the list of inner propagators, so its
  public functions are 4-arity (`inject(propagators, ctx,
  carrier, setter)`) and it is dispatched via the
  `{Composite, propagators}` tuple that `new/1` returns.

  The facade's `inject_with`/`extract_with` pattern-matches on
  this tuple shape to route to the 4-arg form, while atom-only
  propagators route to the 3-arg behaviour callback.

  ## Public API

  | Function | Role |
  |---|---|
  | `new/1` | **Application** (OTel API MUST) — Create a Composite Propagator (L278-L285) |
  | `fields/1` | **Application** (OTel API MAY) — Aggregated inner-propagator Fields (L133-L152) |
  | `inject/4`, `extract/4` | **SDK** (dispatch target) — invoked via `TextMap.inject_with/4` / `extract_with/4` on the `{Composite, propagators}` tuple |

  ## References

  - OTel Context §Composite Propagator: `opentelemetry-specification/specification/context/api-propagators.md` L259-L305
  - OTel Context §Fields: `opentelemetry-specification/specification/context/api-propagators.md` L133-L152
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_propagator_text_map_composite.erl`
  """

  @typedoc """
  An inner propagator for composition.

  Either a module implementing the
  `Otel.API.Propagator.TextMap` behaviour (no options) or a
  `{module, options}` tuple for a configured propagator
  (currently only `Composite` itself uses this shape).
  """
  @type propagator :: module() | {module(), term()}

  @doc """
  **Application** (OTel API MUST) — "Create a Composite
  Propagator" (`api-propagators.md` L278-L285).

  Returns a `{Composite, propagators}` tuple suitable for
  registration via `Otel.API.Propagator.TextMap.set_propagator/1`.
  Inner propagators are invoked in the order given.
  """
  @spec new(propagators :: [propagator()]) :: {module(), [propagator()]}
  def new(propagators) when is_list(propagators) do
    {__MODULE__, propagators}
  end

  @doc """
  **SDK** (dispatch target) — "Composite Inject"
  (`api-propagators.md` L297-L305).

  Calls each inner propagator's inject in order on the same
  carrier, threading the carrier through the reduction.

  Not called directly by application code — invoked via
  `Otel.API.Propagator.TextMap.inject_with/4` when the global
  propagator is a `{Composite, propagators}` tuple.
  """
  @spec inject(
          propagators :: [propagator()],
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          setter :: Otel.API.Propagator.TextMap.setter()
        ) :: Otel.API.Propagator.TextMap.carrier()
  def inject(propagators, ctx, carrier, setter) do
    Enum.reduce(propagators, carrier, fn propagator, acc ->
      Otel.API.Propagator.TextMap.inject_with(propagator, ctx, acc, setter)
    end)
  end

  @doc """
  **SDK** (dispatch target) — "Composite Extract"
  (`api-propagators.md` L286-L296).

  Calls each inner propagator's extract in order, threading
  the context through the reduction so later propagators see
  earlier extractions.

  Not called directly by application code — invoked via
  `Otel.API.Propagator.TextMap.extract_with/4` when the global
  propagator is a `{Composite, propagators}` tuple.
  """
  @spec extract(
          propagators :: [propagator()],
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Ctx.t()
  def extract(propagators, ctx, carrier, getter) do
    Enum.reduce(propagators, ctx, fn propagator, acc_ctx ->
      Otel.API.Propagator.TextMap.extract_with(propagator, acc_ctx, carrier, getter)
    end)
  end

  @doc """
  **Application** (OTel API MAY) — Fields (`api-propagators.md`
  L133-L152).

  Returns the deduplicated union of header keys used by all
  inner propagators. Deduplication prevents callers that
  pre-read carriers from reading the same key twice when two
  inner propagators share a field (rare but possible with
  custom compositions).
  """
  @spec fields(propagators :: [propagator()]) :: [String.t()]
  def fields(propagators) do
    propagators
    |> Enum.flat_map(fn
      {module, _opts} -> module.fields()
      module -> module.fields()
    end)
    |> Enum.uniq()
  end
end
