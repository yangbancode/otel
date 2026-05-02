defmodule Otel.InstrumentationScope do
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

  ## API shape: struct, not variadic arguments

  Each signal's `Get a Tracer` / `Get a Meter` / `Get a
  Logger` spec requires that the API
  *"MUST be structured to accept a variable number of
  attributes, including none"*:

  - `trace/api.md` §TracerProvider operations
  - `metrics/api.md` L147-L149
  - `logs/api.md` L91-L93

  We satisfy this MUST by passing a single
  `%Otel.InstrumentationScope{}` struct whose
  `attributes: %{}` field accepts 0 to N entries:

      get_logger(%InstrumentationScope{})
      # => 0 attributes

      get_logger(%InstrumentationScope{attributes: %{"env" => "prod"}})
      # => 1 attribute

      get_logger(%InstrumentationScope{attributes: %{...}})
      # => N attributes

  ### Interpretation

  *"structured to accept a variable number of attributes"*
  describes the API's **acceptance range** — it must permit 0
  to N attributes — not a particular caller syntax. Different
  language implementations meet this with different shapes:
  Java uses a builder, Go uses variadic options, Python uses
  `**kwargs`, Erlang uses positional arguments, and Elixir
  uses a struct with a map field.

  ### Why struct rather than keyword list

  - **Dialyzer checks fields at compile time** —
    `%InstrumentationScope{name: 123}` is rejected;
    `get_logger(name: 123)` would not be.
  - **Struct equality supports the spec's cache rule.** The
    *"identical vs distinct"* Tracer/Meter/Logger rule (spec:
    same parameters → same instance) maps directly to Elixir
    map equality on the four struct fields, evaluated in one
    operation with no keyword-order sensitivity.
  - **Consistency across signals.** `TracerProvider.get_tracer/1`,
    `MeterProvider.get_meter/0,1`, and
    `LoggerProvider.get_logger/0,1` all accept the same shape,
    so callers learn one pattern.

  ### Divergence from opentelemetry-erlang

  Erlang's `otel_tracer_provider:get_tracer/4` takes positional
  arguments (`Name, Vsn, SchemaUrl, Extra`). We accept a
  struct instead. Both satisfy the spec MUST; the struct is
  the Elixir-idiomatic choice for grouped identity tuples and
  matches the broader ecosystem (`%Ecto.Schema{}`,
  `%Plug.Conn{}`, `%Date{}`).

  ## References

  - OTel Instrumentation Scope: `opentelemetry-specification/specification/common/instrumentation-scope.md`
  - Tracer creation mapping: `opentelemetry-specification/specification/trace/api.md` L118–L139
  - `attributes` field origin: OTEP `0201-scope-attributes.md` (added in spec v1.13.0)
  """

  use Otel.Common.Types

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
          attributes: %{String.t() => primitive_any()}
        }

  defstruct name: "",
            version: "",
            schema_url: "",
            attributes: %{}
end
