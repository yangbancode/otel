# View Deferred Features

## Question

How to implement View features deferred from the View System Decision: duplicate conflict resolution with View, View vs advisory precedence, and Instrument Enabled with Drop aggregation?

## Decision

### Duplicate Conflict Resolution with View

When a duplicate instrument is registered (same downcased name, same scope) with different identifying fields:

1. **Description-only conflict** — If only description differs and a matching View sets description, the warning is suppressed. Otherwise warn with a suggestion to configure a View.
2. **Distinguishable conflict** — If kind differs, warn with a suggestion to configure a renaming View.
3. **Unresolvable conflict** — If unit or other fields differ, emit a generic warning and use the first-seen instrument.

`Instrument.conflict_type/2` classifies the conflict. `Meter.warn_duplicate/4` dispatches to the appropriate warning. In all cases the SDK returns the first-seen functional instrument.

### View vs Advisory Precedence

View configuration always takes precedence over advisory parameters for the same aspect:

- **Bucket boundaries**: `Stream.merge_advisory_boundaries/2` uses `Map.put_new/3`, so View-provided boundaries are never overwritten.
- **Attribute keys**: `Stream.from_view/2` falls back to `advisory_attribute_keys/1` only when the View has no `:attribute_keys`.

When no View matches, advisory parameters are used as defaults via `Stream.from_instrument/1` and `Stream.resolve/1`.

Fix: added `validate_advisory_param/2` clause for `:attributes` — previously this advisory key was dropped as unknown despite being read downstream.

### Instrument Enabled with Drop Aggregation

`Meter.enabled?/2` accepts `instrument_name` in opts:

- Returns `true` by default (no opts or no instrument_name).
- For registered instruments: returns `false` when all resolved streams use `Drop` aggregation.
- For unregistered instruments: returns `false` when all matching Views specify `Drop` aggregation.
- Returns `true` when at least one stream/view uses a non-Drop aggregation.

## Compliance

- [Metrics SDK](../compliance.md)
  * Duplicate Instrument Registration — L923, L926, L928
  * Instrument Advisory Parameters — L996, L1009
  * Instrument Enabled — L1029, L1037
