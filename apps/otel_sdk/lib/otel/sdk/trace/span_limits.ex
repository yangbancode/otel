defmodule Otel.SDK.Trace.SpanLimits do
  @moduledoc """
  Configurable limits for Span data.

  Prevents unbounded growth of span attributes, events, and links.
  Excess items are silently discarded. A log message SHOULD be
  emitted at most once per span when items are discarded (L873-875).
  """

  @type t :: %__MODULE__{
          attribute_count_limit: pos_integer(),
          attribute_value_length_limit: pos_integer() | :infinity,
          event_count_limit: pos_integer(),
          link_count_limit: pos_integer(),
          attribute_per_event_limit: pos_integer(),
          attribute_per_link_limit: pos_integer()
        }

  defstruct attribute_count_limit: 128,
            attribute_value_length_limit: :infinity,
            event_count_limit: 128,
            link_count_limit: 128,
            attribute_per_event_limit: 128,
            attribute_per_link_limit: 128
end
