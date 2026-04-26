defmodule Otel.SDK.Logs.LogRecord do
  @moduledoc """
  SDK-side `ReadWriteLogRecord` (`logs/sdk.md` §ReadWriteLogRecord
  L298-L319 + §ReadableLogRecord L277-L296).

  Spec L294-L296 explicitly suggests *"a new interface or
  (immutable) value type"* separate from the API LogRecord —
  this module is that type. Constructed inside
  `Otel.SDK.Logs.Logger.build_log_record/3` from the
  caller-supplied `Otel.API.Logs.LogRecord` plus context- and
  state-derived fields, then flowed unchanged through every
  registered processor and exporter.

  ## Fields beyond `Otel.API.Logs.LogRecord`

  | Field | Source | Spec |
  |---|---|---|
  | `trace_id`, `span_id`, `trace_flags` | resolved `Otel.API.Ctx.t()` at emit time | L286-L287 *"trace context fields MUST be populated from the resolved Context"* |
  | `scope` | `Otel.API.InstrumentationScope` of the originating Logger | L282-L283 *"Instrumentation Scope ... (implicitly) associated with the LogRecord"* |
  | `resource` | `Otel.SDK.Resource` of the LoggerProvider | L283 *"Resource information (implicitly) associated"* |
  | `dropped_attributes_count` | size delta after `LogRecordLimits` application | L289-L292 *"Counts for attributes due to collection limits MUST be available for exporters"* |

  The `exception` sidecar from `Otel.API.Logs.LogRecord` is
  **not** present — it is consumed by
  `apply_exception_attributes/1` before this struct is
  constructed and surfaces as `exception.type` / `exception.message`
  attributes per `trace/exceptions.md` §Attributes.

  ## Why a separate struct from `Otel.API.Logs.LogRecord`

  Two reasons (`code-conventions.md` §Layer independence):

  1. The API struct is the *application's* expression of what
     to log — 8 fields covering proto3-defined LogRecord plus
     the project's `exception` sidecar. Adding SDK-state
     fields like `scope` / `resource` to it would push SDK
     concerns into the API surface.
  2. Spec L294-L296 prescribes the separation directly.
  """

  use Otel.API.Common.Types

  @typedoc """
  A LogRecord ready for processor/exporter consumption — the
  spec's ReadWriteLogRecord shape filled in by
  `Otel.SDK.Logs.Logger.build_log_record/3`.

  All defaults are proto3 zero values for the
  `Otel.API.Logs.LogRecord`-mirrored fields; `scope` and
  `resource` default to their respective empty structs so
  the spec MUST in `logs/sdk.md` L281-L283 — *"It MUST
  also be able to access the Instrumentation Scope and
  Resource information ... associated with the LogRecord"*
  — holds on every record without needing nil-guards in
  processors and exporters.
  """
  @type t :: %__MODULE__{
          timestamp: non_neg_integer(),
          observed_timestamp: non_neg_integer(),
          severity_number: Otel.API.Logs.severity_number(),
          severity_text: Otel.API.Logs.severity_level(),
          body: primitive_any(),
          attributes: %{String.t() => primitive() | [primitive()]},
          event_name: String.t(),
          dropped_attributes_count: non_neg_integer(),
          trace_id: Otel.API.Trace.TraceId.t(),
          span_id: Otel.API.Trace.SpanId.t(),
          trace_flags: Otel.API.Trace.SpanContext.trace_flags(),
          scope: Otel.API.InstrumentationScope.t(),
          resource: Otel.SDK.Resource.t()
        }

  defstruct timestamp: 0,
            observed_timestamp: 0,
            severity_number: 0,
            severity_text: "",
            body: nil,
            attributes: %{},
            event_name: "",
            dropped_attributes_count: 0,
            trace_id: 0,
            span_id: 0,
            trace_flags: 0,
            scope: %Otel.API.InstrumentationScope{},
            resource: %Otel.SDK.Resource{}
end
