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
  **SDK** — Build an Exemplar. Pass `:ctx` to auto-fill
  `:trace_id` / `:span_id` from the current Span; explicit
  `:trace_id` / `:span_id` in `opts` always win.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    {ctx, opts} = Map.pop(opts, :ctx)

    ctx_fields =
      if ctx do
        {trace_id, span_id} = extract_trace_info(ctx)
        %{trace_id: trace_id, span_id: span_id}
      else
        %{}
      end

    defaults = %{
      value: 0,
      time: 0,
      filtered_attributes: %{},
      span_id: nil,
      trace_id: nil
    }

    struct!(__MODULE__, defaults |> Map.merge(ctx_fields) |> Map.merge(opts))
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
