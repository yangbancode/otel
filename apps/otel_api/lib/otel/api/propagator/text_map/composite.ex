defmodule Otel.API.Propagator.TextMap.Composite do
  @moduledoc """
  Composite propagator that groups multiple TextMapPropagators.

  Inject calls each propagator's inject in order on the same carrier.
  Extract calls each propagator's extract in order, threading the
  context through each (later propagators see earlier extractions).
  """

  @behaviour Otel.API.Propagator.TextMap

  @type propagator :: module() | {module(), term()}

  @doc """
  Creates a composite propagator from a list of propagators.

  Returns a tuple suitable for global registration.
  """
  @spec new(propagators :: [propagator()]) :: {module(), [propagator()]}
  def new(propagators) when is_list(propagators) do
    {__MODULE__, propagators}
  end

  @impl true
  @spec inject(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          setter :: Otel.API.Propagator.TextMap.setter()
        ) :: Otel.API.Propagator.TextMap.carrier()
  def inject(ctx, carrier, setter) do
    inject([], ctx, carrier, setter)
  end

  @doc false
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

  @impl true
  @spec extract(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Ctx.t()
  def extract(ctx, carrier, getter) do
    extract([], ctx, carrier, getter)
  end

  @doc false
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

  @impl true
  @spec fields() :: [String.t()]
  def fields do
    fields([])
  end

  @doc false
  @spec fields(propagators :: [propagator()]) :: [String.t()]
  def fields(propagators) do
    propagators
    |> Enum.flat_map(fn
      {module, _opts} -> module.fields()
      module when is_atom(module) -> module.fields()
    end)
    |> Enum.uniq()
  end
end
