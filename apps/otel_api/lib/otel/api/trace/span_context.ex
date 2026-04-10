defmodule Otel.API.Trace.SpanContext do
  @moduledoc """
  Immutable context of a Span.

  Contains the trace_id, span_id, trace_flags, and tracestate needed
  to propagate span identity across process and network boundaries.
  IDs are stored as non-negative integers, matching opentelemetry-erlang.
  """

  @type trace_id :: non_neg_integer()
  @type span_id :: non_neg_integer()
  @type trace_flags :: non_neg_integer()

  @type t :: %__MODULE__{
          trace_id: trace_id(),
          span_id: span_id(),
          trace_flags: trace_flags(),
          tracestate: :otel_tracestate.t(),
          is_remote: boolean()
        }

  defstruct trace_id: 0,
            span_id: 0,
            trace_flags: 0,
            tracestate: [],
            is_remote: false

  @doc """
  Creates a new SpanContext.
  """
  @spec new(trace_id(), span_id(), trace_flags(), :otel_tracestate.t()) :: t()
  def new(trace_id, span_id, trace_flags \\ 0, tracestate \\ []) do
    %__MODULE__{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags,
      tracestate: tracestate
    }
  end

  @doc """
  Returns `true` if the SpanContext has a non-zero trace_id and span_id.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{trace_id: trace_id, span_id: span_id}) do
    trace_id != 0 and span_id != 0
  end

  @doc """
  Returns `true` if the SpanContext was propagated from a remote parent.
  """
  @spec remote?(t()) :: boolean()
  def remote?(%__MODULE__{is_remote: is_remote}), do: is_remote

  @doc """
  Returns `true` if the sampled flag (lowest bit of trace_flags) is set.
  """
  @spec sampled?(t()) :: boolean()
  def sampled?(%__MODULE__{trace_flags: trace_flags}) do
    Bitwise.band(trace_flags, 1) != 0
  end

  @doc """
  Returns the trace_id as a 32-character lowercase hex string.
  """
  @spec trace_id_hex(t()) :: binary()
  def trace_id_hex(%__MODULE__{trace_id: trace_id}) do
    trace_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(32, "0")
  end

  @doc """
  Returns the span_id as a 16-character lowercase hex string.
  """
  @spec span_id_hex(t()) :: binary()
  def span_id_hex(%__MODULE__{span_id: span_id}) do
    span_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(16, "0")
  end
end
