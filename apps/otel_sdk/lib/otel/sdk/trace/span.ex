defmodule Otel.SDK.Trace.Span do
  @moduledoc """
  Internal SDK span record stored in ETS.

  This struct holds all mutable span data during its lifecycle.
  Not exposed to users — they interact through SpanContext.
  """

  @type t :: %__MODULE__{
          trace_id: non_neg_integer(),
          span_id: non_neg_integer(),
          tracestate: Otel.API.Trace.TraceState.t(),
          parent_span_id: non_neg_integer() | nil,
          parent_span_is_remote: boolean() | nil,
          name: String.t(),
          kind: Otel.API.Trace.SpanKind.t(),
          start_time: integer(),
          end_time: integer() | nil,
          attributes: Otel.API.Attribute.attributes(),
          events: [Otel.API.Trace.Event.t()],
          links: [Otel.API.Trace.Link.t()],
          status: Otel.API.Trace.Status.t(),
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
    :instrumentation_scope,
    tracestate: %Otel.API.Trace.TraceState{},
    kind: :internal,
    start_time: 0,
    attributes: %{},
    events: [],
    links: [],
    status: %Otel.API.Trace.Status{},
    trace_flags: 0,
    is_recording: true,
    span_limits: %Otel.SDK.Trace.SpanLimits{},
    processors: []
  ]
end
