defmodule Otel.API.InstrumentationScope do
  @moduledoc """
  Identifies the instrumentation library that produced telemetry.
  """

  use Otel.API.Types

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          schema_url: String.t(),
          attributes: %{String.t() => primitive() | [primitive()]}
        }

  defstruct name: "",
            version: "",
            schema_url: "",
            attributes: %{}
end
