defmodule Otel.SDK.Trace.Sampler do
  @moduledoc """
  Sampler behaviour and dispatch.

  A sampler decides whether a span should be recorded and/or sampled
  (propagated). Custom samplers implement this behaviour.

  ## Built-in samplers

  - `Otel.SDK.Trace.Sampler.AlwaysOn` — every span sampled
  - `Otel.SDK.Trace.Sampler.AlwaysOff` — every span dropped
  - `Otel.SDK.Trace.Sampler.ParentBased` — defer to parent's sampled bit
  - `Otel.SDK.Trace.Sampler.TraceIdRatioBased` — probabilistic by trace_id

  ## Deferred Development-status features

  - **AlwaysRecord sampler decorator.** Spec
    `trace/sdk.md` L608-L630 (Status: Development, added
    v1.51 #4699) defines a sampler decorator that wraps any
    sampler and forces `record_only` (recording without
    propagation) when the inner sampler returns `drop`. Not
    implemented — no in-tree consumer. When stabilised it
    will live as `Otel.SDK.Trace.Sampler.AlwaysRecord`.
  """

  use Otel.API.Common.Types

  @type sampling_decision :: :drop | :record_only | :record_and_sample

  @type attributes :: %{String.t() => primitive_any()}

  @type sampling_result :: {
          sampling_decision(),
          attributes(),
          Otel.API.Trace.TraceState.t()
        }

  @type config :: term()
  @type opts :: term()
  @type description :: String.t()

  @type t :: {module(), description(), config()}

  @doc """
  Initializes sampler configuration from options.
  """
  @callback setup(opts :: opts()) :: config()

  @doc """
  Returns a human-readable description of the sampler.
  """
  @callback description(config :: config()) :: description()

  @doc """
  Returns a sampling decision for a span to be created.
  """
  @callback should_sample(
              ctx :: Otel.API.Ctx.t(),
              trace_id :: Otel.API.Trace.TraceId.t(),
              links :: [Otel.API.Trace.Link.t()],
              name :: String.t(),
              kind :: Otel.API.Trace.SpanKind.t(),
              attributes :: attributes(),
              config :: config()
            ) :: sampling_result()

  @doc """
  Creates a sampler from a spec.

  Accepts `{module, opts}` and returns `{module, description, config}`.
  """
  @spec new(spec :: {module(), opts()}) :: t()
  def new({module, sampler_opts}) do
    config = module.setup(sampler_opts)
    {module, module.description(config), config}
  end

  @doc """
  Invokes the sampler's should_sample callback.
  """
  @spec should_sample(
          sampler :: t(),
          ctx :: Otel.API.Ctx.t(),
          trace_id :: Otel.API.Trace.TraceId.t(),
          links :: [Otel.API.Trace.Link.t()],
          name :: String.t(),
          kind :: Otel.API.Trace.SpanKind.t(),
          attributes :: attributes()
        ) ::
          sampling_result()
  def should_sample({module, _description, config}, ctx, trace_id, links, name, kind, attributes) do
    module.should_sample(ctx, trace_id, links, name, kind, attributes, config)
  end

  @doc """
  Returns the sampler's description.
  """
  @spec description(sampler :: t()) :: description()
  def description({_module, desc, _config}), do: desc
end
