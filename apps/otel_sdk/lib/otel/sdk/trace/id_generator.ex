defmodule Otel.SDK.Trace.IdGenerator do
  @moduledoc """
  Behaviour for trace ID and span ID generation.

  The SDK randomly generates IDs by default. Custom implementations
  can be provided via TracerProvider configuration.
  """

  @doc """
  Generates a new TraceId.
  """
  @callback generate_trace_id() :: Otel.API.Trace.TraceId.t()

  @doc """
  Generates a new SpanId.
  """
  @callback generate_span_id() :: Otel.API.Trace.SpanId.t()
end
