# Logs SDK

## Question

How to implement Logs SDK on BEAM? LoggerProvider SDK, LogRecordProcessor (Simple/Batch), LogRecordExporter, ReadableLogRecord, LogRecord limits?

## Decision

TBD

## Compliance

- [Logs SDK](../compliance/logs-sdk.md)
  * LoggerProvider — L55, L59, L60
  * LoggerProvider Creation — L65
  * Logger Creation — L69, L72, L74, L79, L80, L81
  * Configuration — L92, L97
  * Shutdown — L140, L141, L144, L147, L152
  * ForceFlush — L163, L163, L167, L172
  * Emit a LogRecord (SDK) — L226, L228, L231
  * Enabled (SDK) — L256, L267, L270
  * ReadableLogRecord — L279, L281, L285, L289
  * ReadWriteLogRecord — L302
  * LogRecord Limits — L323, L326, L331, L345, L347
  * LogRecordProcessor — L363, L365
  * OnEmit — L397, L409
  * Enabled (Processor) — L439
  * Processor Shutdown — L462, L463, L466, L469, L471
  * Processor ForceFlush — L480, L484, L486, L487, L492, L495, L500
  * Built-in Processors — L507, L510
  * Simple Processor — L521
  * Batching Processor — L534
  * LogRecordExporter — L559, L563
  * Export — L582, L586
  * Exporter ForceFlush — L620, L622, L627
  * Exporter Shutdown — L637, L638, L640
  * Concurrency Requirements (SDK) — L654, L657, L659
