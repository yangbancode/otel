# Span Limits

## Question

How to implement span-specific limits (EventCountLimit, LinkCountLimit, SpanLimits class) separate from common attribute limits?

## Decision

### Struct

A simple struct with all configurable limits per spec (L834-876).

| Field | Default | Description |
|---|---|---|
| `attribute_count_limit` | 128 | Max attributes per span |
| `attribute_value_length_limit` | `:infinity` | Max string/bytes attribute value length |
| `event_count_limit` | 128 | Max events per span |
| `link_count_limit` | 128 | Max links per span |
| `attribute_per_event_limit` | 128 | Max attributes per event |
| `attribute_per_link_limit` | 128 | Max attributes per link |

### Usage

SpanLimits is part of TracerProvider config. When the SDK creates a span, it enforces these limits. Excess attributes/events/links are silently discarded with a one-time log per span (L873-875).

### Module: `Otel.SDK.Trace.SpanLimits`

Location: `apps/otel_sdk/lib/otel/sdk/trace/span_limits.ex`

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * Span Limits — L836, L841, L845, L846, L873, L875
