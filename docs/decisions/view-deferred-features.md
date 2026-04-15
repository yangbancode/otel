# View Deferred Features

## Question

How to implement View features deferred from the View System Decision: duplicate conflict resolution with View, View vs advisory precedence, and Instrument Enabled with Drop aggregation?

## Decision

TBD — requires:
- Duplicate conflict resolution: description override via View avoids warning (L923), renaming recipe for distinguishable instruments (L926), pass-through for unresolvable conflicts (L928)
- View takes precedence over advisory for same aspect (L996)
- ExplicitBucketBoundaries advisory honored when no View matches (L1009)
- Instrument Enabled returns false when all resolved views use Drop (L1029, L1037)

## Compliance

- [Metrics SDK](../compliance.md)
  * Duplicate Instrument Registration — L923, L926, L928
  * Instrument Advisory Parameters — L996, L1009
  * Instrument Enabled — L1029, L1037
