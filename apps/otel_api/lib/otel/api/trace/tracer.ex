defmodule Otel.API.Trace.Tracer do
  @moduledoc """
  Tracer behaviour for creating Spans.

  A Tracer is represented as a `{module, config}` tuple where
  the module implements this behaviour.
  """

  @type t :: {module(), term()}

  @doc """
  Starts a new span. Returns the SpanContext of the created span.
  """
  @callback start_span(
              ctx :: Otel.API.Ctx.t(),
              tracer :: t(),
              name :: String.t(),
              opts :: keyword()
            ) ::
              Otel.API.Trace.SpanContext.t()

  @doc """
  Returns whether the tracer is enabled.

  Accepts optional keyword opts for future extensibility per spec
  (L209: "the API MUST be structured in a way for parameters to
  be added").
  """
  @callback enabled?(tracer :: t(), opts :: keyword()) :: boolean()
end
