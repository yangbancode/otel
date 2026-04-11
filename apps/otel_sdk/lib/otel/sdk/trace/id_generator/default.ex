defmodule Otel.SDK.Trace.IdGenerator.Default do
  @moduledoc """
  Default ID generator using Erlang's `:rand.uniform/1`.

  Generates random non-zero integers:
  - trace_id: 128-bit (1 to 2^128 - 1)
  - span_id: 64-bit (1 to 2^64 - 1)
  """

  @behaviour Otel.SDK.Trace.IdGenerator

  @trace_id_max Bitwise.bsl(2, 127) - 1
  @span_id_max Bitwise.bsl(2, 63) - 1

  @spec generate_trace_id() :: non_neg_integer()
  @impl true
  def generate_trace_id do
    :rand.uniform(@trace_id_max)
  end

  @spec generate_span_id() :: non_neg_integer()
  @impl true
  def generate_span_id do
    :rand.uniform(@span_id_max)
  end
end
