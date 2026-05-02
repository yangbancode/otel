defmodule Otel.Trace.Event do
  @moduledoc """
  A timestamped event recorded on a Span (spec `trace/api.md`
  §Add Events, Status: **Stable**, L520-L558).

  An Event is structurally defined by a name, a timestamp, and
  zero or more attributes (spec L525-L531). Events are
  immutable; an Elixir struct satisfies that naturally. All
  functions on this module are safe for concurrent use (spec
  L843-L853).

  Per spec L540-L542 *"If no custom timestamp is provided by the
  user, the implementation automatically sets the time at which
  this API is called on the event"* — `new/3`'s `timestamp`
  parameter defaults eagerly to `System.system_time(:nanosecond)`
  when omitted. Values are nanoseconds since the Unix epoch,
  matching OTLP `time_unix_nano` with no conversion needed.

  Per spec L548-L552 timestamps MAY be before the span start or
  after span end when supplied explicitly by the caller; no
  normalisation is performed.

  Spec L544-L546 *"Events SHOULD preserve the order in which
  they are recorded"* is a Span-level concern, not this struct's.

  ## References

  - OTel Trace API §Add Events: `opentelemetry-specification/specification/trace/api.md` L520-L558
  - OTLP proto Span.Event: `opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto` L222-L240
  """

  use Otel.Common.Types

  @typedoc """
  A Span Event struct.

  Fields:

  - `name` — name of the event.
  - `timestamp` — Unix epoch **nanoseconds** (OTLP
    `time_unix_nano`). Either the time at which the event was
    added (default via `new/3`) or a custom value supplied by
    the caller (spec L528-L529).
  - `attributes` — zero or more attributes describing the event.
    Values follow OTel attribute rules (primitives and
    homogeneous arrays; no maps, no heterogeneous arrays).
  - `dropped_attributes_count` — counter populated by the SDK
    when span limits truncate the attribute map; mirrors OTLP
    `Span.Event.dropped_attributes_count`. Application code
    constructing an Event via `new/3` leaves this at the default
    `0`.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          timestamp: non_neg_integer(),
          attributes: %{String.t() => primitive_any()},
          dropped_attributes_count: non_neg_integer()
        }

  defstruct name: "", timestamp: 0, attributes: %{}, dropped_attributes_count: 0

  @doc """
  Build an Event struct for `Otel.Trace.Span.add_event/2`.

  Creates a new `Event` with optional attributes and timestamp.
  `timestamp` defaults to `System.system_time(:nanosecond)` —
  per spec L540-L542 the implementation sets the time when the
  API is called if the caller doesn't provide one.

  Values are Unix epoch **nanoseconds** (OTLP `time_unix_nano`,
  a `fixed64` unsigned proto3 field). The typespec is
  `non_neg_integer()` enforcing the unsigned invariant at the
  API boundary.
  """
  @spec new(
          name :: String.t(),
          attributes :: %{String.t() => primitive_any()},
          timestamp :: non_neg_integer()
        ) :: t()
  def new(name, attributes \\ %{}, timestamp \\ System.system_time(:nanosecond)) do
    %__MODULE__{
      name: name,
      timestamp: timestamp,
      attributes: attributes
    }
  end
end
