defmodule Otel.API.InstrumentationScope do
  @moduledoc """
  Identifies the instrumentation library that produced telemetry.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          schema_url: String.t(),
          attributes: %{Otel.API.Attribute.key() => Otel.API.Attribute.value()}
        }

  defstruct name: "",
            version: "",
            schema_url: "",
            attributes: %{}
end
