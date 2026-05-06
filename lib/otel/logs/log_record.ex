defmodule Otel.Logs.LogRecord do
  @moduledoc """
  LogRecord data model (`logs/data-model.md` §"Log and Event
  Record Definition" L155-L451; Status: **Stable**).

  Represents a single log record flowing through the Logs API.
  Sibling to `Otel.Logs.Logger` — the Logger *emits*
  LogRecords (`api.md` L101), consistent with the spec's
  treatment of the two as peer concepts across `api.md` and
  `data-model.md`.

  The struct mirrors the OTLP wire format: field defaults
  match the proto3 zero values for `fixed64 *_unix_nano`,
  `SEVERITY_NUMBER_UNSPECIFIED`, `string`, and `repeated
  KeyValue`. Nothing needs a `|| default` fallback downstream
  — the struct IS the default.

  ## Public API

  | Function / Type | Role |
  |---|---|
  | `t:t/0` | **Application** (data model) — LogRecord struct type |

  Construct via `Otel.Logs.LogRecord.new/1` — the canonical
  constructor that fills proto3-aligned defaults plus
  runtime-derived `scope` / `resource`. The `defstruct`
  declares only field names; defaults live exclusively in
  `new/1` so all initialization flows through one place.

  ## Field defaults — proto3-aligned

  | Field | Default | Basis |
  |---|---|---|
  | `timestamp` | `0` | proto `fixed64`; `logs.proto` L141 *"Value of 0 indicates unknown or missing timestamp"* |
  | `observed_timestamp` | `0` | proto `fixed64`; `logs.proto` L158 same language. SDK fills with current time at emit per proto MUST (L149) |
  | `severity_number` | `0` | proto `SeverityNumber` enum; `logs.proto` L88 `SEVERITY_NUMBER_UNSPECIFIED = 0`; `data-model.md` L271 *"MAY represent unspecified"* |
  | `severity_text` | `""` | proto `string`; `logs.proto` L167 "[Optional]" |
  | `body` | `nil` | proto `AnyValue` message type — proto3 messages use presence tracking; Elixir `nil` ≡ absent. Spec `common.md` L50 explicitly permits `nil` as a valid AnyValue ("empty value if supported by the language") — `body: nil` conflates "missing" and "null-as-AnyValue", but both mean the same thing to downstream processors and wire format |
  | `attributes` | `%{}` | proto `repeated KeyValue`; empty map ≡ empty repeated after encoding |
  | `event_name` | `""` | proto `string`; `logs.proto` L221 *"Presence of event_name identifies this record as an event"* — empty = non-Event |
  | `trace_id` | `0` | proto `bytes` (16 bytes, all zeros = invalid); `data-model.md` §Field TraceId; `logs.proto` L199-L204. Populated by the SDK from the resolved `Context` per spec L208-L213 |
  | `span_id` | `0` | proto `bytes` (8 bytes, all zeros = invalid); `data-model.md` §Field SpanId; `logs.proto` L206-L211. Same SDK handling as `trace_id` |
  | `trace_flags` | `0` | proto `fixed32`; `data-model.md` §Field TraceFlags; `logs.proto` L213. Sampled bit (0x01) per W3C Trace Context |
  | `exception` | `nil` | Not in proto LogRecord; API-layer MAY-accepted field per `api.md` L131. SDK converts to `exception.*` attributes |

  `nil` appears as a default only for `body` (spec-permitted
  AnyValue null) and `exception` (sidecar sentinel). All other
  fields use proto3 zero-values, which are correctly
  distinguished by consumers as "missing" per the proto
  comments cited above.

  ## Trace context fields

  `trace_id`, `span_id`, `trace_flags` are LogRecord fields
  per `data-model.md` §Field TraceId / SpanId / TraceFlags
  (sections covered by L208-L232) and proto `logs.proto`
  L199-L213. They are present on the struct for data-model
  parity with the wire format and the SDK LogRecord — the
  SDK populates the SDK-side LogRecord from the resolved
  `Otel.Ctx.t/0` per spec L208-L213 (*"trace context
  fields MUST be populated from the resolved Context (either
  the explicitly passed Context or the current Context)"*),
  not from these input fields. Callers do not need to set
  them and the SDK ignores any value supplied here.

  ## References

  - OTel Logs Data Model: `opentelemetry-specification/specification/logs/data-model.md`
  - OTel Logs API §Emit a LogRecord: `opentelemetry-specification/specification/logs/api.md` L111-L131
  - OTLP proto `LogRecord`: `opentelemetry-proto/opentelemetry/proto/logs/v1/logs.proto` L136-L226
  - OTLP proto `AnyValue` nil: `opentelemetry-proto/opentelemetry/proto/common/v1/common.proto` L25-L53
  """

  use Otel.Common.Types

  @typedoc """
  A LogRecord — the data model flowing through the Logs API.

  Fields mirror `data-model.md` §"Log and Event Record
  Definition" L155-L451 plus the MAY-accepted `exception`
  sidecar from `api.md` L131.

  All fields have spec-aligned defaults (see module doc's
  Field defaults table), so `%Otel.Logs.LogRecord{}` is a
  valid empty record representing "all fields missing".
  """
  @type t :: %__MODULE__{
          timestamp: non_neg_integer(),
          observed_timestamp: non_neg_integer(),
          severity_number: Otel.Logs.severity_number(),
          severity_text: Otel.Logs.severity_level(),
          body: primitive_any(),
          attributes: %{String.t() => primitive_any()},
          event_name: String.t(),
          trace_id: Otel.Trace.TraceId.t(),
          span_id: Otel.Trace.SpanId.t(),
          trace_flags: Otel.Trace.SpanContext.trace_flags(),
          exception: Exception.t() | nil,
          scope: Otel.InstrumentationScope.t(),
          resource: Otel.Resource.t(),
          dropped_attributes_count: non_neg_integer()
        }

  defstruct [
    :timestamp,
    :observed_timestamp,
    :severity_number,
    :severity_text,
    :body,
    :attributes,
    :event_name,
    :trace_id,
    :span_id,
    :trace_flags,
    :exception,
    :scope,
    :resource,
    :dropped_attributes_count
  ]

  @doc """
  **Application** — Construct a LogRecord. Proto3 zero-value
  defaults plus runtime-derived `scope` / `resource` are
  applied; caller may override any field via `opts`.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    defaults = %{
      timestamp: 0,
      observed_timestamp: 0,
      severity_number: 0,
      severity_text: "",
      body: nil,
      attributes: %{},
      event_name: "",
      trace_id: 0,
      span_id: 0,
      trace_flags: 0,
      exception: nil,
      scope: Otel.InstrumentationScope.new(),
      resource: Otel.Resource.new(),
      dropped_attributes_count: 0
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end
end
