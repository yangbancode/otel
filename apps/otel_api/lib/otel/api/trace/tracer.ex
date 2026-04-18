defmodule Otel.API.Trace.Tracer do
  @moduledoc """
  Tracer behaviour for creating Spans.

  A Tracer is represented as a `{module, config}` tuple where
  the module implements this behaviour.

  All functions are safe for concurrent use.
  """

  @type t :: {module(), term()}

  @typedoc """
  Options accepted by `enabled?/2`.

  The spec (L209) requires the API to accept optional parameters for
  future extensibility. Keys (all MAY-support):
  - `:context` — evaluation context
  - `:attributes` — attributes that would be attached to the span
  """
  @type enabled_opt ::
          {:context, Otel.API.Ctx.t()}
          | {:attributes, Otel.API.Attribute.attributes()}

  @type enabled_opts :: [enabled_opt()]

  @doc """
  Starts a new span. Returns the SpanContext of the created span.

  Options: see `Otel.API.Trace.Span.start_opts/0`.
  """
  @callback start_span(
              ctx :: Otel.API.Ctx.t(),
              tracer :: t(),
              name :: String.t(),
              opts :: Otel.API.Trace.Span.start_opts()
            ) ::
              Otel.API.Trace.SpanContext.t()

  @doc """
  Returns whether the tracer is enabled.

  Accepts optional keyword opts for future extensibility per spec
  (L209: "the API MUST be structured in a way for parameters to
  be added").
  """
  @callback enabled?(tracer :: t(), opts :: enabled_opts()) :: boolean()
end
