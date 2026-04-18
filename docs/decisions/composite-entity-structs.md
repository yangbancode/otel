# Composite Entity Structs

## Question

How do we represent the OpenTelemetry spec's composite entities — `Link`,
`Event`, `Status`, `LogRecord`, `Measurement` — in Elixir, and where do
they live in the module namespace?

## Decision

Every spec entity that consists of **multiple named fields with distinct
semantic meaning** becomes a `defstruct` module, per the Q1 branch of the
[Type Representation Policy](type-representation-policy.md). These entities
replace previous tuple / opts / anonymous-map representations throughout
the API surface, the SDK, and the exporter.

### Modules introduced

| Module | Fields | Spec |
|---|---|---|
| `Otel.API.Trace.Link` | `context :: SpanContext.t()`, `attributes :: Attribute.attributes()` | `trace/api.md` "Specifying Links" |
| `Otel.API.Trace.Event` | `name :: String.t()`, `timestamp :: integer()`, `attributes :: Attribute.attributes()` | `trace/api.md` "Add Events" |
| `Otel.API.Trace.Status` | `code :: :unset \| :ok \| :error`, `description :: String.t()` | `trace/api.md` "Set Status" |
| `Otel.API.Logs.LogRecord` | 9 optional fields (timestamp, observed_timestamp, context, severity_number, severity_text, body, attributes, event_name, exception) | `logs/data-model.md` |
| `Otel.API.Metrics.Measurement` | `value :: number()`, `attributes :: Attribute.attributes()` | `metrics/api.md` (observable callbacks) |

Each module defines a narrow `new/*` constructor where useful and relies on
pattern matching elsewhere. No runtime validation — per happy-path policy,
callers construct valid values and we destructure them in function heads.

### API shape changes

- `Otel.API.Trace.Span.add_link/2` takes a `Link.t()` instead of
  `(linked_ctx, attributes)`.
- `Otel.API.Trace.Span.add_event/2` takes an `Event.t()` instead of
  `(name, opts)`.
- `Otel.API.Trace.Span.set_status/2` takes a `Status.t()` instead of
  `(code, description)`.
- `start_span` option `:links` is `[Link.t()]` instead of
  `[{SpanContext, attributes}]`.
- Observable instrument callbacks return `[Measurement.t()]` instead of
  `[{value, attributes}]`.
- `Otel.API.Logs.Logger.emit/{2,3}` takes a `LogRecord.t()` instead of the
  anonymous `log_record` map type. That map type is removed.

Synchronous metric recording (`Counter.add/4`, `Histogram.record/4`, etc.)
retains its `(value, attributes)` separate-arg shape. `Measurement` is
only used on the observable-callback return surface.

### Internal representation

The SDK consumes these structs end-to-end:

- `Otel.SDK.Trace.Span` stores `events: [Event.t()]`, `links: [Link.t()]`,
  `status: Status.t()`.
- `Otel.SDK.Logs` processors receive `LogRecord.t()` (with internal
  enrichment preserved as plain-map overlays — see note below).
- `Otel.SDK.Metrics.Meter` aggregates `Measurement.t()` values returned
  from observable callbacks.
- `Otel.Exporter.OTLP.Encoder` pattern-matches the structs directly in
  `encode_event/1`, `encode_link/1`, `encode_status/1`, and their
  counterparts for logs and metrics.

The SDK's post-enrichment log record (trace correlation fields, scope,
resource, dropped-attributes count) remains a plain `map()` carrying both
the `LogRecord` fields and the SDK-only fields. Promoting that internal
representation to its own struct is a future SDK refinement and does not
affect the API boundary decided here.

### Default values

- `Link` — `%Link{context: %SpanContext{}, attributes: %{}}`
- `Event` — `%Event{name: "", timestamp: 0, attributes: %{}}`; `Event.new/3`
  supplies `System.system_time(:nanosecond)` when timestamp is nil.
- `Status` — `%Status{code: :unset, description: ""}`. The default status
  for a new SDK Span is `%Status{}` (unset).
- `LogRecord` — all fields default to `nil` / `%{}`.
- `Measurement` — `%Measurement{value: 0, attributes: %{}}`.

### `Otel.API.Metrics.Instrument` — landed separately

The type-representation-policy entity catalog lists `Instrument` as a
struct. It lands in its own Decision: see
[api-instrument-struct.md](api-instrument-struct.md). Creation now
returns an `Otel.API.Metrics.Instrument.t()` handle that carries its
meter; synchronous recording takes `(instrument, value, attrs)`.

## Modules

- `apps/otel_api/lib/otel/api/trace/link.ex`
- `apps/otel_api/lib/otel/api/trace/event.ex`
- `apps/otel_api/lib/otel/api/trace/status.ex`
- `apps/otel_api/lib/otel/api/logs/log_record.ex`
- `apps/otel_api/lib/otel/api/metrics/measurement.ex`

## Compliance

- [Trace API](../compliance.md) — `# Trace API` Span Operations: Add Events,
  Add Link, Set Status (lines L155-178)
- [Logs API](../compliance.md) — `# Logs API` LogRecord fields (lines L1402-1448)
- [Metrics API](../compliance.md) — `# Metrics API` Observable instrument
  callbacks (lines around L920-940)

Supersedes no prior Decision. The earlier `span-operations.md`,
`logs-api.md`, `asynchronous-instruments-and-callbacks.md` describe the
original tuple/opts/map shapes and will be revisited if their compliance
citations need updates as a result of this change.
