defmodule Otel.API.Trace.Link do
  @moduledoc """
  A link from the current Span to another `SpanContext` (spec
  `trace/api.md` §Link, Status: **Stable**, L803-L834).

  A Link pairs a `SpanContext` identifying the target span with a
  set of attributes describing the relationship. Linked spans may
  be part of the same trace or a different trace (spec L805-L807).

  Per spec L815-L821 the API accepts the linked `SpanContext` and
  optional `Attributes` either as individual parameters or as an
  **immutable object encapsulating them** — this module is that
  immutable object; `new/2` is the canonical constructor.

  Per spec L853 Links are immutable; an Elixir struct satisfies
  that naturally, and concurrency-safety (SHOULD) follows for the
  same reason.

  Note: spec `#### Specifying links` (L442-L447) is a separate
  concern — it describes how Link values are passed at Span
  creation, which is the Span builder's responsibility, not this
  type module's.

  ## Public API

  | Function | Role |
  |---|---|
  | `new/2` | **Local helper** (not in spec) |

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

  @doc """
  **Local helper** (not in spec).

  Creates a new `Link` from a `SpanContext` and optional
  attributes. Per spec L815-L821 this is the "immutable object
  encapsulating them" form of the Link-recording API.
  """
  @spec new(
          context :: Otel.API.Trace.SpanContext.t(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: t()
  def new(%Otel.API.Trace.SpanContext{} = context, attributes \\ %{}) do
    %__MODULE__{context: context, attributes: attributes}
  end
end
