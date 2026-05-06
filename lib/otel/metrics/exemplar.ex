defmodule Otel.Metrics.Exemplar do
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

  defstruct [:value, :time, :filtered_attributes, :span_id, :trace_id]

  @doc """
  **SDK** — Build an Exemplar from struct fields. Reservoirs that
  want to attach the current trace context call `trace_info/1`
  first and pass the resulting `:trace_id` / `:span_id`.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    defaults = %{
      value: 0,
      time: 0,
      filtered_attributes: %{},
      span_id: nil,
      trace_id: nil
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end

  @doc """
  **SDK** — Extract the active span's `{trace_id, span_id}` from
  `ctx`, returning `{nil, nil}` when no valid span is present.
  Reservoirs call this before `new/1` to attach trace context.
  """
  @spec trace_info(ctx :: Otel.Ctx.t()) ::
          {Otel.Trace.TraceId.t() | nil, Otel.Trace.SpanId.t() | nil}
  def trace_info(ctx) do
    %Otel.Trace.SpanContext{trace_id: trace_id, span_id: span_id} =
      Otel.Trace.current_span(ctx)

    if Otel.Trace.TraceId.valid?(trace_id) and Otel.Trace.SpanId.valid?(span_id) do
      {trace_id, span_id}
    else
      {nil, nil}
    end
  end
end
