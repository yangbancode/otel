# View Deferred Features

## Question

How to implement View features deferred from the View System Decision: duplicate conflict resolution with View, View vs advisory precedence, and Instrument Enabled with Drop aggregation?

## Decision

### Duplicate Conflict Resolution with View

When a duplicate instrument is registered (same downcased name, same scope) with different identifying fields:

1. **Fully identical** — All identifying fields and advisory match: silently return first-seen (no warning needed).
2. **Advisory-only conflict** — Identifying fields identical but advisory differs: warn per MUST requirement (sdk.md L990) and return first-seen advisory.
3. **Description-only conflict** — If only description differs and a matching View sets description, the warning is suppressed. Otherwise warn with a suggestion to configure a View.
4. **Distinguishable conflict** — If kind differs (but unit matches), warn with a suggestion to configure a renaming View.
5. **Unresolvable conflict** — If unit differs (regardless of kind), emit a generic warning and use the first-seen instrument.

`Instrument.conflict_type/2` classifies identifying-field conflicts. `Meter.warn_duplicate/4` dispatches to the appropriate warning using guard clauses for the advisory and identical cases, and pattern matching for the rest. In all cases the SDK returns the first-seen functional instrument.

### View vs Advisory Precedence

View configuration always takes precedence over advisory parameters for the same aspect:

- **Bucket boundaries**: When a View explicitly specifies an aggregation (e.g., ExplicitBucketHistogram), advisory boundaries are ignored entirely — even if the View does not supply custom boundaries (sdk.md L1003-1005). Advisory boundaries are only used when no View matched or the matching View uses default aggregation (`stream.aggregation == nil`).
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
  * Duplicate Instrument Registration — L923, L926, L928, L990
  * Instrument Advisory Parameters — L996, L1003, L1009
  * Instrument Enabled — L1029, L1037
