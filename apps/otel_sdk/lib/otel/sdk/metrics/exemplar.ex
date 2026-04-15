defmodule Otel.SDK.Metrics.Exemplar do
  @moduledoc """
  An Exemplar is a recorded measurement that links metric data
  to trace context. Exemplars are sampled from measurements by
  ExemplarReservoirs and attached to metric data points during
  collection.
  """

  @type t :: %__MODULE__{
          value: number(),
          time: integer(),
          filtered_attributes: map(),
          span_id: binary() | nil,
          trace_id: binary() | nil
        }

  defstruct value: 0,
            time: 0,
            filtered_attributes: %{},
            span_id: nil,
            trace_id: nil

  @spec new(
          value :: number(),
          time :: integer(),
          filtered_attributes :: map(),
          ctx :: Otel.API.Ctx.t()
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

  @spec extract_trace_info(ctx :: Otel.API.Ctx.t()) ::
          {non_neg_integer() | nil, non_neg_integer() | nil}
  defp extract_trace_info(ctx) do
    %Otel.API.Trace.SpanContext{trace_id: trace_id, span_id: span_id} =
      Otel.API.Trace.current_span(ctx)

    if trace_id != 0 and span_id != 0 do
      {trace_id, span_id}
    else
      {nil, nil}
    end
  end
end
