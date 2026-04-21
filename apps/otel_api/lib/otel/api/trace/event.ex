defmodule Otel.API.Trace.Event do
  @moduledoc """
  A timestamped event recorded on a Span (spec `trace/api.md`
  §Add Events, Status: **Stable**, L520-L558).

  An Event is structurally defined by a name, a timestamp, and
  zero or more attributes (spec L525-L531). Events are
  immutable; an Elixir struct satisfies that naturally, and
  concurrency-safety follows (spec L851).

  Per spec L540-L542 *"If no custom timestamp is provided by the
  user, the implementation automatically sets the time at which
  this API is called on the event"* — `new/3` defaults the
  `timestamp` to `System.system_time(:nanosecond)` when `nil` is
  passed. Timestamps are nanoseconds since the Unix epoch,
  matching OTLP `time_unix_nano` with no conversion needed.

  Per spec L548-L552 timestamps MAY be before the span start or
  after span end when supplied explicitly by the caller; no
  normalisation is performed.

  Spec L544-L546 *"Events SHOULD preserve the order in which
  they are recorded"* is a Span-level concern, not this struct's.

  ## Public API

  | Function | Role |
  |---|---|
  | `new/3` | **Local helper** (not in spec) |

  ## References

  - OTel Trace API §Add Events: `opentelemetry-specification/specification/trace/api.md` L520-L558
  """

  use Otel.API.Common.Types

  @typedoc """
  A Span Event struct (spec `trace/api.md` §Add Events,
  L525-L531).

  Fields:

  - `name` — name of the event.
  - `timestamp` — nanoseconds since the Unix epoch. Either the
    time at which the event was added (default via `new/3`) or
    a custom value supplied by the caller (spec L528-L529).
  - `attributes` — zero or more attributes describing the event.
    Values follow OTel attribute rules (primitives and
    homogeneous arrays; no maps, no heterogeneous arrays).
  """
  @type t :: %__MODULE__{
          name: String.t(),
          timestamp: integer(),
          attributes: %{String.t() => primitive() | [primitive()]}
        }

  defstruct name: "", timestamp: 0, attributes: %{}

  @doc """
  **Local helper** (not in spec).

  Creates a new `Event` with optional attributes and timestamp.
  Per spec L540-L542, if `timestamp` is `nil` the implementation
  sets it to the current system time in nanoseconds. Explicit
  integer timestamps (including `0`) are preserved verbatim —
  spec L548-L552 does not require normalisation of caller-
  supplied values.
  """
  @spec new(
          name :: String.t(),
          attributes :: %{String.t() => primitive() | [primitive()]},
          timestamp :: integer() | nil
        ) :: t()
  def new(name, attributes \\ %{}, timestamp \\ nil) do
    %__MODULE__{
      name: name,
      timestamp: timestamp || System.system_time(:nanosecond),
      attributes: attributes
    }
  end
end
