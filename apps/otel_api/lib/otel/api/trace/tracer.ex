defmodule Otel.API.Trace.Tracer do
  @moduledoc """
  Tracer behaviour for creating Spans.

  A Tracer is represented as a `{module, config}` tuple where
  the module implements this behaviour.
  """

  alias Otel.API.Ctx
  alias Otel.API.Trace.SpanContext

  @type t :: {module(), term()}

  @doc """
  Starts a new span. Returns the SpanContext of the created span.
  """
  @callback start_span(Ctx.t(), t(), String.t(), keyword()) :: SpanContext.t()

  @doc """
  Returns whether the tracer is enabled.

  Accepts optional keyword opts for future extensibility per spec
  (L209: "the API MUST be structured in a way for parameters to
  be added").
  """
  @callback enabled?(t(), keyword()) :: boolean()
end
