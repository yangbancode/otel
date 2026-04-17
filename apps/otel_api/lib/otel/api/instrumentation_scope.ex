defmodule Otel.API.InstrumentationScope do
  @moduledoc """
  Identifies the instrumentation library that produced telemetry.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          schema_url: String.t() | nil,
          attributes: [Otel.API.Common.Attribute.t()]
        }

  defstruct name: "",
            version: "",
            schema_url: nil,
            attributes: []
end
