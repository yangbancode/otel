defmodule Otel.Metrics.Exemplar do
  @moduledoc """
  An Exemplar is a recorded measurement that links metric data
  to trace context. Exemplars are sampled from measurements by
  ExemplarReservoirs and attached to metric data points during
  collection.

  ## Trace context invariant

  Reservoirs only construct Exemplars after
  `Otel.Metrics.Exemplar.Filter.should_sample?/1` accepts the
  context — that filter passes only when the active span has
  the W3C `trace_flags` sampled bit set, which means the span
  is valid (non-zero `trace_id` / `span_id`). The struct fields
  therefore mirror `Otel.Trace.Span` and `Otel.Logs.LogRecord`:
  `trace_id: TraceId.t()` (no `| nil`), with the proto3
  zero-value `0` as the unset default.
  """

  use Otel.Common.Types

  @type t :: %__MODULE__{
          value: number(),
          time: non_neg_integer(),
          filtered_attributes: %{String.t() => primitive_any()},
          span_id: Otel.Trace.SpanId.t(),
          trace_id: Otel.Trace.TraceId.t()
        }

  defstruct [:value, :time, :filtered_attributes, :span_id, :trace_id]

  @doc """
  **SDK** — Build an Exemplar from struct fields. Reservoirs
  destructure `Otel.Trace.current_span(ctx)` directly to obtain
  `:trace_id` / `:span_id` for the call.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    defaults = %{
      value: 0,
      time: 0,
      filtered_attributes: %{},
      span_id: 0,
      trace_id: 0
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end
end
