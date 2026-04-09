# Logs API

## Question

How to implement LoggerProvider, Logger, Emit LogRecord, and Enabled API on BEAM? How to ensure API works without SDK?

## Decision

TBD

## Compliance

- [Logs API](../compliance/logs-api.md)
  * LoggerProvider — L59, L64
  * Get a Logger — L70, L85, L88, L92
  * Logger — L103, L107
  * Emit a LogRecord — L117, L118, L119, L122, L123, L124, L125, L126, L127
  * Enabled — L135, L140, L143, L144, L145, L147, L152
  * Optional and Required Parameters — L161, L164
  * Concurrency Requirements — L172, L175
