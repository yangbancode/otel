defmodule Otel.API.Trace.Event do
  @moduledoc """
  A timestamped event recorded on a Span — spec: trace/api.md (Add Events).

  An Event has a name, a timestamp (nanoseconds since the Unix epoch) and a
  set of attributes. If no timestamp is provided to `new/3`, the current
  system time is used (spec L537-539).
  """

  use Otel.API.Types

  @type t :: %__MODULE__{
          name: String.t(),
          timestamp: integer(),
          attributes: %{String.t() => primitive() | [primitive()]}
        }

  defstruct name: "", timestamp: 0, attributes: %{}

  @doc """
  Creates a new Event.

  If `timestamp` is `nil`, the current system time in nanoseconds is used.
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
