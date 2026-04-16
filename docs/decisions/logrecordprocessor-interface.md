# LogRecordProcessor Interface

## Question

How to define the LogRecordProcessor behaviour on BEAM? OnEmit, Enabled, Shutdown, ForceFlush callbacks and ReadableLogRecord/ReadWriteLogRecord interfaces?

## Decision

TBD

## Compliance

- [Logs SDK](../compliance.md)
  * ReadableLogRecord — L279, L281, L285, L289
  * ReadWriteLogRecord — L302
  * LogRecordProcessor — L363, L365
  * OnEmit — L397, L409
  * Enabled (Processor) — L439
  * Processor Shutdown — L462, L463, L466, L469, L471
  * Processor ForceFlush — L480, L484, L486, L487, L492, L495, L500
  * Built-in Processors — L507, L510
