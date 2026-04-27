defmodule Otel.SDK.Trace.IdGenerator.Default do
  @moduledoc """
  Default ID generator using Erlang's `:rand.uniform/1`.

  Generates random non-zero integers:
  - trace_id: 128-bit (1 to 2^128 - 1)
  - span_id: 64-bit (1 to 2^64 - 1)
  """

  @behaviour Otel.SDK.Trace.IdGenerator

  # `bsl(1, n) - 1` reads as "n bits all set" — clearer than
  # the equivalent `bsl(2, n - 1) - 1`.
  @trace_id_max Bitwise.bsl(1, 128) - 1
  @span_id_max Bitwise.bsl(1, 64) - 1

  @spec generate_trace_id() :: Otel.API.Trace.TraceId.t()
  @impl true
  def generate_trace_id do
    Otel.API.Trace.TraceId.new(:rand.uniform(@trace_id_max))
  end

  @spec generate_span_id() :: Otel.API.Trace.SpanId.t()
  @impl true
  def generate_span_id do
    Otel.API.Trace.SpanId.new(:rand.uniform(@span_id_max))
  end
end
