defmodule Otel.API.Logs.LogRecord do
  @moduledoc """
  LogRecord data model (`logs/data-model.md` §"Log and Event
  Record Definition" L155-L451; Status: **Stable**).

  Represents a single log record flowing through the Logs API.
  Sibling to `Otel.API.Logs.Logger` — the Logger *emits*
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

  `new/0` / `new/1` are not provided; use `%Otel.API.Logs.LogRecord{...}`
  at the callsite. The struct's default values make all fields
  truly optional without helper ceremony.

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
  | `exception` | `nil` | Not in proto LogRecord; API-layer MAY-accepted field per `api.md` L131. SDK converts to `exception.*` attributes |

  `nil` appears as a default only for `body` (spec-permitted
  AnyValue null) and `exception` (sidecar sentinel). All other
  fields use proto3 zero-values, which are correctly
  distinguished by consumers as "missing" per the proto
  comments cited above.

  ## References

  - OTel Logs Data Model: `opentelemetry-specification/specification/logs/data-model.md`
  - OTel Logs API §Emit a LogRecord: `opentelemetry-specification/specification/logs/api.md` L111-L131
  - OTLP proto `LogRecord`: `opentelemetry-proto/opentelemetry/proto/logs/v1/logs.proto` L136-L226
  - OTLP proto `AnyValue` nil: `opentelemetry-proto/opentelemetry/proto/common/v1/common.proto` L25-L53
  """

  use Otel.API.Common.Types

  @typedoc """
  A LogRecord — the data model flowing through the Logs API.

  Fields mirror `data-model.md` §"Log and Event Record
  Definition" L155-L451 plus the MAY-accepted `exception`
  sidecar from `api.md` L131.

  All fields have spec-aligned defaults (see module doc's
  Field defaults table), so `%Otel.API.Logs.LogRecord{}` is a
  valid empty record representing "all fields missing".
  """
  @type t :: %__MODULE__{
          timestamp: non_neg_integer(),
          observed_timestamp: non_neg_integer(),
          severity_number: Otel.API.Logs.severity_number(),
          severity_text: Otel.API.Logs.severity_level(),
          body: primitive_any(),
          attributes: %{String.t() => primitive() | [primitive()]},
          event_name: String.t(),
          exception: Exception.t() | nil
        }

  defstruct timestamp: 0,
            observed_timestamp: 0,
            severity_number: 0,
            severity_text: "",
            body: nil,
            attributes: %{},
            event_name: "",
            exception: nil
end
