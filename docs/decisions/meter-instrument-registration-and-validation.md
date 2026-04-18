# Meter: Instrument Registration & Validation

## Question

How does the SDK Meter handle instrument creation, name validation, duplicate registration, and advisory parameters?

## Decision

### Instrument Storage

ETS table owned by MeterProvider, shared across all Meters from the same provider. Instruments are keyed by `{scope, downcased_name}` — scope provides namespace isolation between distinct Meters, downcased name handles case-insensitive matching.

### Name Validation

Meter validates instrument name against the ABNF syntax:
- First character must be alphabetic
- Subsequent: alphanumeric, `_`, `.`, `-`, `/`
- Max 255 characters
- Not null or empty

Invalid names log a warning but still register (non-fatal, per erlang reference).

### Duplicate Detection

On `create_*`, the SDK checks if an instrument with the same downcased name exists for the same Meter scope:
- **First registration**: inserts into ETS, returns instrument reference
- **Identical instrument** (same kind, unit, description): returns existing instrument, no warning
- **Duplicate with conflicts** (different kind/unit/description): returns existing instrument, logs warning

First-seen wins for name casing and advisory parameters.

### Advisory Parameter Validation

- `explicit_bucket_boundaries`: only valid for Histogram, must be sorted list of numbers
- Invalid advisory params: log warning, proceed without them

### Unit and Description

- Null/missing unit treated as empty string `""`
- Null/missing description treated as empty string `""`
- No validation on either (SHOULD NOT validate)

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Metrics.Meter` | `apps/otel_sdk/lib/otel/sdk/metrics/meter.ex` | SDK Meter with registration |
| `Otel.API.Metrics.Instrument` | `apps/otel_api/lib/otel/api/metrics/instrument.ex` | Shared struct + helpers (see [api-instrument-struct.md](api-instrument-struct.md)) |

## Compliance

- [Metrics SDK](../compliance.md)
  * Meter (Stable) — L872
  * Duplicate Instrument Registration — L912, L919, L923, L926, L928, L942
  * Name Conflict — L950
  * Instrument Name — L962, L965
  * Instrument Unit — L971, L972
  * Instrument Description — L977, L979
  * Instrument Advisory Parameters (Stable) — L985, L986, L990, L996, L1009
  * Instrument Enabled — L1029, L1037
  * Numerical Limits Handling — L1842, L1845
