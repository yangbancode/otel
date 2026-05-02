defmodule Otel.Trace.Link do
  @moduledoc """
  A link from the current Span to another `SpanContext` (spec
  `trace/api.md` §Link, Status: **Stable**, L803-L834).

  A Link pairs a `SpanContext` identifying the target span with a
  set of attributes describing the relationship. Linked spans may
  be part of the same trace or a different trace (spec L805-L807).

  Per spec L815-L821 the API accepts the linked `SpanContext` and
  optional `Attributes` either as individual parameters or as an
  **immutable object encapsulating them** — this struct is that
  immutable object. Construct with a struct literal:

      %Otel.Trace.Link{context: span_ctx}
      %Otel.Trace.Link{context: span_ctx, attributes: %{"key" => "val"}}

  No dedicated constructor is provided; there is no construction-
  time normalisation or opaque boundary that would require one
  (same rationale as `Otel.InstrumentationScope`).

  Per spec L853 Links are immutable; an Elixir struct satisfies
  that naturally. All functions on this module are safe for
  concurrent use.

  ## Design notes

  ### Zero-TraceId / zero-SpanId links permitted by design

  Spec L820-L823 SHOULD:

  > *"Implementations SHOULD record links containing
  > SpanContext with empty TraceId or SpanId (all zeros)
  > as long as either the attribute set or TraceState is
  > non-empty."*

  This struct does no validation on `context` — any
  `SpanContext`, including one with all-zero `trace_id` or
  `span_id`, is accepted. Validating at this type module
  would pre-reject spec-compliant Links whose recording
  decision belongs to the SDK's span-storage path, where the
  full Link data (context + attributes + tracestate) is
  available and where the policy "retain or drop" applies.

  ## References

  - OTel Trace API §Link: `opentelemetry-specification/specification/trace/api.md` L803-L834
  - OTLP proto Span.Link: `opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto` L252-L290
  """

  use Otel.Common.Types

  @typedoc """
  A Link struct (spec `trace/api.md` §Link, L809-L813).

  Fields:

  - `context` — the `SpanContext` of the Span being linked
    to. Zero-TraceId / zero-SpanId contexts are permitted;
    see the module's `## Design notes` for the rationale.
  - `attributes` — zero or more attributes describing the
    relationship. Values follow OTel attribute rules.
  - `dropped_attributes_count` — counter populated by the SDK
    when span limits truncate the attribute map; mirrors OTLP
    `Span.Link.dropped_attributes_count`. Application code
    constructing a Link via the struct literal leaves this at
    the default `0`.
  """
  @type t :: %__MODULE__{
          context: Otel.Trace.SpanContext.t(),
          attributes: %{String.t() => primitive_any()},
          dropped_attributes_count: non_neg_integer()
        }

  defstruct context: %Otel.Trace.SpanContext{},
            attributes: %{},
            dropped_attributes_count: 0
end
