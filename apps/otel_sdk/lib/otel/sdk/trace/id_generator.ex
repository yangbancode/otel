defmodule Otel.SDK.Trace.IdGenerator do
  @moduledoc """
  Behaviour for trace ID and span ID generation.

  The SDK randomly generates IDs by default. Custom implementations
  can be provided via TracerProvider configuration.
  """

  @doc """
  Generates a 128-bit trace ID.
  """
  @callback generate_trace_id() :: non_neg_integer()

  @doc """
  Generates a 64-bit span ID.
  """
  @callback generate_span_id() :: non_neg_integer()
end
