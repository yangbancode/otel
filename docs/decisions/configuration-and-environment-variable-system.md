# Configuration & Environment Variable System

## Question

How to implement the OTel configuration system (env vars + programmatic config) on BEAM? How to merge env vars, Application config, and defaults?

## Decision

TBD

## Compliance

- [Environment Variables](../compliance/environment-variables.md)
  * Implementation Guidelines — [L49](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L49)
  * Implementation Guidelines — [L50](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L50)
  * Implementation Guidelines — [L56](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L56)
  * Parsing Empty Value — [L60](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L60)
  * Boolean — [L67](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L67)
  * Boolean — [L68](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L68)
  * Boolean — [L70](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L70)
  * Boolean — [L72](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L72)
  * Boolean — [L73](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L73)
  * Boolean — [L75](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L75)
  * Numeric — [L89](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L89)
  * Enum — [L103](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L103)
  * Enum — [L106](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L106)
  * General SDK Configuration — [L118](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L118)
  * General SDK Configuration — [L120](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L120)
  * Batch LogRecord Processor — [L167](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L167)
  * Batch LogRecord Processor — [L168](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L168)
  * Batch LogRecord Processor — [L169](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L169)
  * Batch LogRecord Processor — [L170](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L170)
  * Attribute Limits — [L174](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L174)
  * Attribute Limits — [L181](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L181)
  * Attribute Limits — [L182](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L182)
  * LogRecord Limits — [L203](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L203)
  * LogRecord Limits — [L204](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L204)
  * Exporter Selection — [L243](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L243)
  * Exporter Selection — [L244](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L244)
  * Exporter Selection — [L245](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L245)
  * Exporter Selection — [L254](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L254)
  * Language Specific — [L359](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L359)
