defmodule Otel.API.Trace.InstrumentationScope do
  @moduledoc """
  Identifies the instrumentation library that produced telemetry.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          schema_url: String.t() | nil
        }

  defstruct name: "",
            version: "",
            schema_url: nil
end
