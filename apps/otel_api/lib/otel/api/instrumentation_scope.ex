defmodule Otel.API.InstrumentationScope do
  @moduledoc """
  A logical unit of software identified by `(name, version, schema_url,
  attributes)` that emits telemetry (spec
  `common/instrumentation-scope.md`, Status: **Stable**).

  The tuple SHOULD uniquely identify the emitting software unit and is
  used to obtain a `Tracer`, `Meter`, or `Logger`.

  ## Name SHOULD be specified

  Per `common/instrumentation-scope.md` L27-L28:

  > *"The instrumentation scope's name SHOULD be specified."*

  The struct defaults `name: ""` to support the default-scope pattern
  used by `Otel.API.Metrics.MeterProvider.get_meter/0`,
  `Otel.API.Logs.LoggerProvider.get_logger/0`, and similar zero-arity
  entry points, but an empty name represents an **unspecified** scope.
  Instrumentation libraries SHOULD supply a meaningful name —
  typically the library's own module path — when creating a Tracer,
  Meter, or Logger, since downstream consumers (samplers, exporters,
  backends) rely on the scope name to disambiguate telemetry by
  origin.

  `version`, `schema_url`, and `attributes` are optional.

  ## References

  - OTel Instrumentation Scope: `opentelemetry-specification/specification/common/instrumentation-scope.md`
  - Tracer creation mapping: `opentelemetry-specification/specification/trace/api.md` L118–L139
  - `attributes` field origin: OTEP `0201-scope-attributes.md` (added in spec v1.13.0)
  """

  use Otel.API.Common.Types

  @typedoc """
  An instrumentation scope tuple (spec `common/instrumentation-scope.md`).

  Fields:

  - `name` — SHOULD be specified to identify the scope. An empty string
    is permitted by this struct and represents an **unspecified** scope,
    consistent with `Otel.API.Trace.get_tracer/0` allowing a default
    `%InstrumentationScope{}`. The spec recommends specifying it.
  - `version` — Optional. Version of the instrumentation library or
    scope. Empty string when unspecified.
  - `schema_url` — Optional. SHOULD identify the Telemetry Schema the
    scope's emitted telemetry conforms to. Empty string when
    unspecified.
  - `attributes` — Optional. Additional scope-identifying key/value
    pairs (OTEP 0201, added in spec v1.13.0). Values follow OTel
    attribute rules: primitives and homogeneous arrays only, no maps
    and no heterogeneous arrays. Empty map when unspecified.
  """
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
