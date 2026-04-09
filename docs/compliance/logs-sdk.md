# Logs SDK

> Ref: [logs/sdk.md](../references/opentelemetry-specification/v1.55.0/logs/sdk.md)

### LoggerProvider
- [ ] All language implementations MUST provide an SDK — [L55](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L55)
- [ ] LoggerProvider MUST provide a way to allow a Resource to be specified — [L59](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L59)
- [ ] If Resource is specified, it SHOULD be associated with all LogRecords produced — [L60](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L60)

### LoggerProvider Creation
- [ ] SDK SHOULD allow creation of multiple independent LoggerProviders — [L65](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L65)

### Logger Creation
- [ ] It SHOULD only be possible to create Logger instances through a LoggerProvider — [L69](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L69)
- [ ] LoggerProvider MUST implement the Get a Logger API — [L72](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L72)
- [ ] Input provided by user MUST be used to create InstrumentationScope stored on Logger — [L74](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L74)
- [ ] If invalid name, a working Logger MUST be returned as fallback — [L79](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L79)
- [ ] Invalid name SHOULD keep the original invalid value — [L80](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L80)
- [ ] A message reporting invalid value SHOULD be logged — [L81](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L81)

### Configuration
- [ ] Configuration (LogRecordProcessors) MUST be owned by LoggerProvider — [L92](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L92)
- [ ] If configuration is updated, it MUST also apply to all already returned Loggers — [L97](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L97)

### Shutdown
- [ ] Shutdown MUST be called only once for each LoggerProvider instance — [L140](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L140)
- [ ] After Shutdown, subsequent attempts to get Logger are not allowed; SDKs SHOULD return no-op Logger — [L141](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L141)
- [ ] Shutdown SHOULD provide a way to let caller know success/failure/timeout — [L144](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L144)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L147](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L147)
- [ ] Shutdown MUST be implemented by invoking Shutdown on all registered LogRecordProcessors — [L152](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L152)

### ForceFlush
- [ ] ForceFlush SHOULD provide a way to let caller know success/failure/timeout — [L163](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L163)
- [ ] ForceFlush SHOULD return ERROR status on error, NO ERROR otherwise — [L163](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L163)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L167](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L167)
- [ ] ForceFlush MUST invoke ForceFlush on all registered LogRecordProcessors — [L172](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L172)

### Emit a LogRecord (SDK)
- [ ] If Observed Timestamp is unspecified, implementation SHOULD set it equal to current time — [L226](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L226)
- [ ] If Exception is provided, SDK MUST by default set attributes from exception with semantic conventions — [L228](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L228)
- [ ] User-provided attributes MUST take precedence and MUST NOT be overwritten by exception-derived attributes — [L231](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L231)

### Enabled (SDK)
- [ ] Enabled MUST return false when there are no registered LogRecordProcessors — [L256](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L256)
- [ ] Enabled MUST return false when all registered processors implement Enabled and each returns false — [L267](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L267)
- [ ] Otherwise, Enabled SHOULD return true — [L270](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L270)

### ReadableLogRecord
- [ ] A function receiving ReadableLogRecord MUST be able to access all information added to the LogRecord — [L279](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L279)
- [ ] ReadableLogRecord MUST also be able to access Instrumentation Scope and Resource — [L281](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L281)
- [ ] Trace context fields MUST be populated from resolved Context when emitted — [L285](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L285)
- [ ] Counts for attributes due to collection limits MUST be available for exporters — [L289](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L289)

### ReadWriteLogRecord
- [ ] A function receiving ReadWriteLogRecord MUST additionally be able to modify Timestamp, ObservedTimestamp, SeverityText, SeverityNumber, Body, Attributes, TraceId, SpanId, TraceFlags, EventName — [L302](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L302)

### LogRecord Limits
- [ ] LogRecord attributes MUST adhere to common rules of attribute limits — [L323](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L323)
- [ ] If SDK implements attribute limits, it MUST provide a way to change them via LoggerProvider configuration — [L326](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L326)
- [ ] Options SHOULD be called LogRecordLimits — [L331](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L331)
- [ ] There SHOULD be a message in SDK log when attribute is discarded due to limit — [L345](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L345)
- [ ] The message MUST be printed at most once per LogRecord — [L347](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L347)

### LogRecordProcessor
- [ ] SDK MUST allow each pipeline to end with an individual exporter — [L363](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L363)
- [ ] SDK MUST allow users to implement and configure custom processors — [L365](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L365)

### OnEmit
- [ ] OnEmit SHOULD NOT block or throw exceptions — [L397](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L397)
- [ ] For processor registered directly on LoggerProvider, logRecord mutations MUST be visible in next registered processors — [L409](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L409)

### Enabled (Processor)
- [ ] Any modifications to parameters inside Enabled MUST NOT be propagated to the caller — [L439](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L439)

### Processor Shutdown
- [ ] Shutdown SHOULD be called only once for each LogRecordProcessor instance — [L462](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L462)
- [ ] After Shutdown, subsequent calls to OnEmit are not allowed; SDKs SHOULD ignore gracefully — [L463](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L463)
- [ ] Shutdown SHOULD provide a way to let caller know success/failure/timeout — [L466](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L466)
- [ ] Shutdown MUST include the effects of ForceFlush — [L469](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L469)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L471](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L471)

### Processor ForceFlush
- [ ] Tasks associated with LogRecords received prior to ForceFlush SHOULD be completed as soon as possible — [L480](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L480)
- [ ] If processor has associated exporter, it SHOULD try to call Export and then ForceFlush on it — [L484](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L484)
- [ ] Built-in LogRecordProcessors MUST do so — [L486](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L486)
- [ ] If timeout is specified, LogRecordProcessor MUST prioritize honoring the timeout — [L487](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L487)
- [ ] ForceFlush SHOULD provide a way to let caller know success/failure/timeout — [L492](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L492)
- [ ] ForceFlush SHOULD only be called in absolutely necessary cases — [L495](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L495)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L500](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L500)

### Built-in Processors
- [ ] Standard SDK MUST implement both simple and batch processors — [L507](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L507)
- [ ] Other common processing scenarios SHOULD be first considered for out-of-process implementation — [L510](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L510)

### Simple Processor
- [ ] Processor MUST synchronize calls to LogRecordExporter's Export — [L521](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L521)

### Batching Processor
- [ ] Processor MUST synchronize calls to LogRecordExporter's Export — [L534](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L534)

### LogRecordExporter
- [ ] Each implementation MUST document the concurrency characteristics the SDK requires — [L559](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L559)
- [ ] LogRecordExporter MUST support Export, ForceFlush, and Shutdown functions — [L563](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L563)

### Export
- [ ] Export MUST NOT block indefinitely, there MUST be a reasonable upper limit (timeout with Failure) — [L582](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L582)
- [ ] Default SDK's LogRecordProcessors SHOULD NOT implement retry logic — [L586](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L586)

### Exporter ForceFlush
- [ ] ForceFlush SHOULD provide a way to let caller know success/failure/timeout — [L620](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L620)
- [ ] ForceFlush SHOULD only be called in absolutely necessary cases — [L622](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L622)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L627](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L627)

### Exporter Shutdown
- [ ] Shutdown SHOULD be called only once for each LogRecordExporter instance — [L637](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L637)
- [ ] After Shutdown, subsequent calls to Export are not allowed and SHOULD return Failure — [L638](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L638)
- [ ] Shutdown SHOULD NOT block indefinitely — [L640](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L640)

### Concurrency Requirements (SDK)
- [ ] LoggerProvider: Logger creation, ForceFlush, and Shutdown MUST be safe to be called concurrently — [L654](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L654)
- [ ] Logger: all methods MUST be safe to be called concurrently — [L657](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L657)
- [ ] LogRecordExporter: ForceFlush and Shutdown MUST be safe to be called concurrently — [L659](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L659)
