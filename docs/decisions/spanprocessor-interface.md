# SpanProcessor Interface

## Question

How to define the SpanProcessor behaviour on BEAM? OnStart, OnEnd, Shutdown, ForceFlush callback signatures?

## Decision

TBD

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * Span Processor — Interface Definition — [L952](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L952)
  * Span Processor — Interface Definition — [L959](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L959)
  * Span Processor — OnStart — [L973](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L973)
  * Span Processor — OnEnd — [L1008](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1008)
  * Span Processor — Shutdown — [L1024](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1024)
  * Span Processor — Shutdown — [L1026](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1026)
  * Span Processor — Shutdown — [L1028](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1028)
  * Span Processor — Shutdown — [L1031](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1031)
  * Span Processor — Shutdown — [L1033](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1033)
  * Span Processor — ForceFlush — [L1041](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1041)
  * Span Processor — ForceFlush — [L1044](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1044)
  * Span Processor — ForceFlush — [L1047](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1047)
  * Span Processor — ForceFlush — [L1052](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1052)
  * Span Processor — ForceFlush — [L1055](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1055)
  * Span Processor — ForceFlush — [L1059](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1059)
  * Built-in Span Processors — [L1066](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1066)
