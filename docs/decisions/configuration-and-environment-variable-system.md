# Configuration & Environment Variable System

## Question

How to implement the OTel configuration system (env vars + programmatic config) on BEAM? How to merge env vars, Application config, and defaults?

## Decision

TBD

## Compliance

- [Environment Variables](../compliance/environment-variables.md)
  * Implementation Guidelines — L49, L50, L56
  * Parsing Empty Value — L60
  * Boolean — L67, L68, L70, L72, L73, L75
  * Numeric — L89
  * Enum — L103, L106
  * General SDK Configuration — L118, L120
  * Batch LogRecord Processor — L167, L168, L169, L170
  * Attribute Limits — L174, L181, L182
  * LogRecord Limits — L203, L204
  * Exporter Selection — L243, L244, L245, L254
  * Language Specific — L359
