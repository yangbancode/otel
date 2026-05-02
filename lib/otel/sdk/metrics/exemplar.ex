defmodule Otel.SDK.Metrics.Exemplar do
  @moduledoc """
  An Exemplar is a recorded measurement that links metric data
  to trace context. Exemplars are sampled from measurements by
  ExemplarReservoirs and attached to metric data points during
  collection.
  """

  use Otel.Common.Types

  @type t :: %__MODULE__{
          value: number(),
          time: non_neg_integer(),
          filtered_attributes: %{String.t() => primitive_any()},
          span_id: Otel.Trace.SpanId.t() | nil,
          trace_id: Otel.Trace.TraceId.t() | nil
        }

  defstruct value: 0,
            time: 0,
            filtered_attributes: %{},
            span_id: nil,
            trace_id: nil

  @spec new(
          value :: number(),
          time :: non_neg_integer(),
          filtered_attributes :: %{String.t() => primitive_any()},
          ctx :: Otel.Ctx.t()
        ) :: t()
  def new(value, time, filtered_attributes, ctx) do
    {trace_id, span_id} = extract_trace_info(ctx)

    %__MODULE__{
      value: value,
      time: time,
      filtered_attributes: filtered_attributes,
      span_id: span_id,
      trace_id: trace_id
    }
  end

  @spec extract_trace_info(ctx :: Otel.Ctx.t()) ::
          {Otel.Trace.TraceId.t() | nil, Otel.Trace.SpanId.t() | nil}
  defp extract_trace_info(ctx) do
    %Otel.Trace.SpanContext{trace_id: trace_id, span_id: span_id} =
      Otel.Trace.current_span(ctx)

    if Otel.Trace.TraceId.valid?(trace_id) and Otel.Trace.SpanId.valid?(span_id) do
      {trace_id, span_id}
    else
      {nil, nil}
    end
  end
end
