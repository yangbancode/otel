defmodule Otel.API.Trace.SpanContext do
  @moduledoc """
  Immutable context of a Span.

  Contains the trace_id, span_id, trace_flags, and tracestate needed
  to propagate span identity across process and network boundaries.
  Per the spec-first type system, `trace_id` and `span_id` are stored
  as `Otel.API.Trace.TraceId.t()` and `Otel.API.Trace.SpanId.t()`
  structs — not native integers.
  """

  @type trace_flags :: non_neg_integer()

  @type t :: %__MODULE__{
          trace_id: Otel.API.Trace.TraceId.t(),
          span_id: Otel.API.Trace.SpanId.t(),
          trace_flags: trace_flags(),
          tracestate: Otel.API.Trace.TraceState.t(),
          is_remote: boolean()
        }

  defstruct trace_id: %Otel.API.Trace.TraceId{bytes: <<0::128>>},
            span_id: %Otel.API.Trace.SpanId{bytes: <<0::64>>},
            trace_flags: 0,
            tracestate: %Otel.API.Trace.TraceState{},
            is_remote: false

  @doc """
  Creates a new SpanContext.
  """
  @spec new(
          trace_id :: Otel.API.Trace.TraceId.t(),
          span_id :: Otel.API.Trace.SpanId.t(),
          trace_flags :: trace_flags(),
          tracestate :: Otel.API.Trace.TraceState.t()
        ) :: t()
  def new(
        %Otel.API.Trace.TraceId{} = trace_id,
        %Otel.API.Trace.SpanId{} = span_id,
        trace_flags \\ 0,
        tracestate \\ %Otel.API.Trace.TraceState{}
      ) do
    %__MODULE__{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags,
      tracestate: tracestate
    }
  end

  @doc """
  Returns `true` if both trace_id and span_id are valid (non-zero).
  """
  @spec valid?(span_ctx :: t()) :: boolean()
  def valid?(%__MODULE__{trace_id: trace_id, span_id: span_id}) do
    Otel.API.Trace.TraceId.valid?(trace_id) and Otel.API.Trace.SpanId.valid?(span_id)
  end

  @doc """
  Returns `true` if the SpanContext was propagated from a remote parent.
  """
  @spec remote?(span_ctx :: t()) :: boolean()
  def remote?(%__MODULE__{is_remote: is_remote}), do: is_remote

  @doc """
  Returns `true` if the sampled flag (lowest bit of trace_flags) is set.
  """
  @spec sampled?(span_ctx :: t()) :: boolean()
  def sampled?(%__MODULE__{trace_flags: trace_flags}) do
    Bitwise.band(trace_flags, 1) != 0
  end

  @doc """
  Returns the trace_id as a 32-character lowercase hex string.
  """
  @spec trace_id_hex(span_ctx :: t()) :: <<_::256>>
  def trace_id_hex(%__MODULE__{trace_id: trace_id}),
    do: Otel.API.Trace.TraceId.to_hex(trace_id)

  @doc """
  Returns the span_id as a 16-character lowercase hex string.
  """
  @spec span_id_hex(span_ctx :: t()) :: <<_::128>>
  def span_id_hex(%__MODULE__{span_id: span_id}),
    do: Otel.API.Trace.SpanId.to_hex(span_id)

  @doc """
  Returns the trace_id as a 16-byte binary.
  """
  @spec trace_id_bytes(span_ctx :: t()) :: <<_::128>>
  def trace_id_bytes(%__MODULE__{trace_id: trace_id}),
    do: Otel.API.Trace.TraceId.to_bytes(trace_id)

  @doc """
  Returns the span_id as an 8-byte binary.
  """
  @spec span_id_bytes(span_ctx :: t()) :: <<_::64>>
  def span_id_bytes(%__MODULE__{span_id: span_id}),
    do: Otel.API.Trace.SpanId.to_bytes(span_id)
end
