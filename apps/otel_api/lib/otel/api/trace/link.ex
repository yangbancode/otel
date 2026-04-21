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
  that naturally, and concurrency-safety (SHOULD) follows for the
  same reason.

  Note: spec `#### Specifying links` (L442-L447) is a separate
  concern — it describes how Link values are passed at Span
  creation, which is the Span builder's responsibility, not this
  type module's.

  ## References

  - OTel Trace API §Link: `opentelemetry-specification/specification/trace/api.md` L803-L834
  """

  use Otel.API.Common.Types

  @typedoc """
  A Link struct (spec `trace/api.md` §Link, L809-L813).

  Fields:

  - `context` — the `SpanContext` of the Span being linked to.
    Per spec L822-L823 implementations SHOULD record links even
    when `context` has zero `trace_id`/`span_id`, as long as
    `attributes` or `context.tracestate` is non-empty; that
    acceptance is implemented at the Span level, not by this
    struct.
  - `attributes` — zero or more attributes describing the
    relationship. Values follow OTel attribute rules (primitives
    and homogeneous arrays; no maps, no heterogeneous arrays).
  """
  @type t :: %__MODULE__{
          context: Otel.API.Trace.SpanContext.t(),
          attributes: %{String.t() => primitive() | [primitive()]}
        }

  defstruct context: %Otel.API.Trace.SpanContext{}, attributes: %{}
end
