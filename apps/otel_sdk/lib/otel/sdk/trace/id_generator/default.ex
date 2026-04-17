defmodule Otel.SDK.Trace.IdGenerator.Default do
  @moduledoc """
  Default ID generator using `:crypto.strong_rand_bytes/1`.

  Generates cryptographically strong random bytes and rerolls the
  all-zero result so every returned ID is valid per the spec.
  """

  @behaviour Otel.SDK.Trace.IdGenerator

  @trace_id_zero <<0::128>>
  @span_id_zero <<0::64>>

  @spec generate_trace_id() :: Otel.API.Trace.TraceId.t()
  @impl true
  def generate_trace_id do
    case :crypto.strong_rand_bytes(16) do
      @trace_id_zero -> generate_trace_id()
      bytes -> Otel.API.Trace.TraceId.new(bytes)
    end
  end

  @spec generate_span_id() :: Otel.API.Trace.SpanId.t()
  @impl true
  def generate_span_id do
    case :crypto.strong_rand_bytes(8) do
      @span_id_zero -> generate_span_id()
      bytes -> Otel.API.Trace.SpanId.new(bytes)
    end
  end
end
