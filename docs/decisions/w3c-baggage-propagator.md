# W3C Baggage Propagator

## Question

How to implement the W3C Baggage propagator (baggage header parsing, percent-encoding)?

## Decision

### Module: `Otel.API.Propagator.TextMap.Baggage`

Location: `apps/otel_api/lib/otel/api/propagator/text_map/baggage.ex`

Implements `Otel.API.Propagator.TextMap` behaviour for W3C Baggage.

### Header Format

```
baggage: key1=value1;metadata1,key2=value2
```

- Entries separated by commas
- Key/value separated by `=`
- Metadata (properties) appended after `;`
- Values are percent-encoded via `URI.encode_www_form/1`

### Inject

1. Get Baggage from context
2. If empty, skip
3. Percent-encode each name and value
4. Append metadata after `;` if non-empty
5. Join entries with `,`

### Extract

1. Read `baggage` header from carrier
2. Split on `,` for entries
3. Split each entry on `;` for value and metadata
4. Split value part on `=` for name and value
5. Percent-decode name and value
6. Merge with existing baggage (remote takes precedence)
7. Invalid entries are silently skipped

## Compliance

- [Baggage](../compliance.md)
  * Propagation — L184
- [API Propagators](../compliance.md)
  * Propagators Distribution — L352
