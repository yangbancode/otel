defmodule Otel.API.Trace.Link do
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

      %Otel.API.Trace.Link{context: span_ctx}
      %Otel.API.Trace.Link{context: span_ctx, attributes: %{"key" => "val"}}

  No dedicated constructor is provided; there is no construction-
  time normalisation or opaque boundary that would require one
  (same rationale as `Otel.API.InstrumentationScope`).

  Per spec L853 Links are immutable; an Elixir struct satisfies
  that naturally. All functions on this module are safe for
  concurrent use (spec L843-L853 *"Link [SHOULD be] documented
  ... safe for concurrent use by default"*).

  Note: spec `#### Specifying links` (L442-L447) is a separate
  concern — it describes how Link values are passed at Span
  creation, which is the Span builder's responsibility, not this
  type module's.

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
  decision belongs to the SDK.

  The SHOULD's *"as long as attributes or TraceState is
  non-empty"* condition is a **recording decision** — it
  belongs to the SDK's span-storage path (the module
  registered via `Otel.API.Trace.Span.set_module/1`), where
  the full Link data (context + attributes + tracestate) is
  available and where the policy "retain or drop" applies.

  API callers can construct any Link; the SDK handles
  recording per SHOULD. A `valid?/1` / `should_record?/1`
  predicate is intentionally **not exposed** on this module
  because the "should record" rule depends on SDK policy,
  not struct shape.

  ## References

  - OTel Trace API §Link: `opentelemetry-specification/specification/trace/api.md` L803-L834
  """

  use Otel.API.Common.Types

  @typedoc """
  A Link struct (spec `trace/api.md` §Link, L809-L813).

  Fields:

  - `context` — the `SpanContext` of the Span being linked
    to. Zero-TraceId / zero-SpanId contexts are permitted;
    see the module's `## Design notes` for the rationale.
  - `attributes` — zero or more attributes describing the
    relationship. Values follow OTel attribute rules (primitives
    and homogeneous arrays; no maps, no heterogeneous arrays).
  - `dropped_attributes_count` — number of attributes the SDK
    discarded for this link because the per-link attribute
    count limit was exceeded (proto `Span.Link` field 5).
    Always `0` on Links constructed by application code; the
    SDK populates it when applying limits at span creation or
    `add_link`.
  """
  @type t :: %__MODULE__{
          context: Otel.API.Trace.SpanContext.t(),
          attributes: %{String.t() => primitive_any()},
          dropped_attributes_count: non_neg_integer()
        }

  defstruct context: %Otel.API.Trace.SpanContext{},
            attributes: %{},
            dropped_attributes_count: 0
end
