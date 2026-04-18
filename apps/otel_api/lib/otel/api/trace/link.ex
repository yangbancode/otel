defmodule Otel.API.Trace.Link do
  @moduledoc """
  A link to a related span — spec: trace/api.md (Specifying Links).

  A Link pairs a `SpanContext` identifying the linked span with a set of
  attributes describing the relationship. Linked spans may be part of the
  same trace or a different trace.
  """

  @type t :: %__MODULE__{
          context: Otel.API.Trace.SpanContext.t(),
          attributes: Otel.API.Attribute.attributes()
        }

  defstruct context: %Otel.API.Trace.SpanContext{}, attributes: %{}

  @doc """
  Creates a new Link from a SpanContext and optional attributes.
  """
  @spec new(
          context :: Otel.API.Trace.SpanContext.t(),
          attributes :: Otel.API.Attribute.attributes()
        ) :: t()
  def new(%Otel.API.Trace.SpanContext{} = context, attributes \\ %{}) do
    %__MODULE__{context: context, attributes: attributes}
  end
end
