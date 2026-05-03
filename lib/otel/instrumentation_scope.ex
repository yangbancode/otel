defmodule Otel.InstrumentationScope do
  @moduledoc """
  Identity of the code that produced telemetry (spec
  `common/instrumentation-scope.md`, Status: **Stable**).

  The spec defines the scope as a `(name, version, schema_url,
  attributes)` tuple that "SHOULD uniquely identify the
  logical unit of software that emits the telemetry." In a
  full plugin ecosystem this would be `opentelemetry_phoenix`,
  `opentelemetry_ecto`, etc. — different identities for each
  instrumentation library.

  ## Hardcoded to the SDK identity (minikube)

  This project ships no plugin ecosystem. All telemetry is
  emitted directly through the SDK's API, so all spans / log
  records / metrics share the same instrumentation scope:
  the SDK itself.

  `defstruct` defaults are hardcoded at compile time from
  `mix.exs`:

  - `name`    — `"otel"` (from `:app` in `mix.exs`)
  - `version` — current SDK version (from `:version` in `mix.exs`)

  Constructed via the struct literal directly:

      %Otel.InstrumentationScope{}
      # => %Otel.InstrumentationScope{
      #      name: "otel",
      #      version: "0.2.0",
      #      schema_url: "",
      #      attributes: %{}
      #    }

  Tests can override individual fields:

      %Otel.InstrumentationScope{schema_url: "https://example.com"}

  ## References

  - OTel Instrumentation Scope: `opentelemetry-specification/specification/common/instrumentation-scope.md`
  - `attributes` field origin: OTEP `0201-scope-attributes.md` (added in spec v1.13.0)
  """

  use Otel.Common.Types

  @name Mix.Project.config()[:app] |> Atom.to_string()
  @version Mix.Project.config()[:version]

  @typedoc """
  An instrumentation scope tuple (spec `common/instrumentation-scope.md`).

  Fields:

  - `name` — identity of the emitting software unit. Hardcoded
    to the SDK app name (`"otel"`) per minikube scope.
  - `version` — version of the emitting software unit.
    Hardcoded to the SDK version (e.g. `"0.2.0"`).
  - `schema_url` — Optional. SHOULD identify the Telemetry
    Schema the scope's emitted telemetry conforms to. Empty
    string when unspecified.
  - `attributes` — Optional. Additional scope-identifying
    key/value pairs (OTEP 0201, added in spec v1.13.0). Values
    follow OTel attribute rules: primitives and homogeneous
    arrays only, no maps and no heterogeneous arrays. Empty
    map when unspecified.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          schema_url: String.t(),
          attributes: %{String.t() => primitive_any()}
        }

  defstruct name: @name,
            version: @version,
            schema_url: "",
            attributes: %{}
end
