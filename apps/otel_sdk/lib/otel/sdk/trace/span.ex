defmodule Otel.SDK.Trace.Span do
  @moduledoc """
  Internal SDK span record stored in ETS.

  This struct holds all mutable span data during its lifecycle.
  Not exposed to users — they interact through SpanContext.
  """

  @type t :: %__MODULE__{
          trace_id: Otel.API.Trace.TraceId.t(),
          span_id: Otel.API.Trace.SpanId.t(),
          tracestate: Otel.API.Trace.TraceState.t(),
          parent_span_id: Otel.API.Trace.SpanId.t() | nil,
          parent_span_is_remote: boolean() | nil,
          name: String.t(),
          kind: Otel.API.Trace.SpanKind.t(),
          start_time: integer(),
          end_time: integer() | nil,
          attributes: [Otel.API.Common.Attribute.t()],
          events: list(),
          links: list(),
          status: {Otel.API.Trace.Span.status_code(), String.t()} | nil,
          trace_flags: non_neg_integer(),
          is_recording: boolean(),
          instrumentation_scope: Otel.API.InstrumentationScope.t() | nil,
          span_limits: Otel.SDK.Trace.SpanLimits.t(),
          processors: [{module(), term()}]
        }

  defstruct [
    :trace_id,
    :span_id,
    :parent_span_id,
    :parent_span_is_remote,
    :name,
    :end_time,
    :status,
    :instrumentation_scope,
    tracestate: %Otel.API.Trace.TraceState{},
    kind: :internal,
    start_time: 0,
    attributes: [],
    events: [],
    links: [],
    trace_flags: 0,
    is_recording: true,
    span_limits: %Otel.SDK.Trace.SpanLimits{},
    processors: []
  ]
end
