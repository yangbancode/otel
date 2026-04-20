defmodule Otel.API.InstrumentationScope do
  @moduledoc """
  Identifies the instrumentation library that produced telemetry.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          schema_url: String.t(),
          attributes: %{String.t() => Otel.API.Types.primitive() | [Otel.API.Types.primitive()]}
        }

  defstruct name: "",
            version: "",
            schema_url: "",
            attributes: %{}
end
