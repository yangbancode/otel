# Trace SDK

> Ref: [trace/sdk.md](../references/opentelemetry-specification/v1.55.0/trace/sdk.md)

### TracerProvider — Tracer Creation

- [ ] It SHOULD only be possible to create Tracer instances through a TracerProvider — [L95](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L95)
- [ ] TracerProvider MUST implement the Get a Tracer API — [L98](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L98)
- [ ] The input provided by the user MUST be used to create an InstrumentationScope instance stored on the Tracer — [L100](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L100)

### TracerProvider — Configuration

- [ ] Configuration (SpanProcessors, IdGenerator, SpanLimits, Sampler) MUST be owned by the TracerProvider — [L113](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L113)
- [ ] If configuration is updated, the updated configuration MUST also apply to all already returned Tracers — [L119](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L119)
- [ ] It MUST NOT matter whether a Tracer was obtained before or after the configuration change — [L120](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L120)

### TracerProvider — Shutdown

- [ ] Shutdown MUST be called only once for each TracerProvider instance — [L161](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L161)
- [ ] After Shutdown, SDKs SHOULD return a valid no-op Tracer for subsequent get-Tracer calls — [L163](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L163)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L165](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L165)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L168](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L168)
- [ ] Shutdown MUST be implemented at least by invoking Shutdown within all internal processors — [L173](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L173)

### TracerProvider — ForceFlush

- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L179](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L179)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L182](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L182)
- [ ] ForceFlush MUST invoke ForceFlush on all registered SpanProcessors — [L187](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L187)

### Additional Span Interfaces

- [ ] Readable span: function MUST be able to access all information that was added to the span — [L242](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L242)
- [ ] Readable span: function MUST be able to access the InstrumentationScope and Resource information — [L249](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L249)
- [ ] Readable span: function MUST also be able to access the InstrumentationLibrary (deprecated) — [L251](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L251)
- [ ] Readable span: function MUST be able to reliably determine whether the Span has ended — [L255](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L255)
- [ ] Readable span: counts for dropped attributes, events and links MUST be available for exporters — [L260](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L260)
- [ ] Readable span: implementations MUST expose at least the full parent SpanContext — [L266](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L266)
- [ ] Read/write span: it MUST be possible to obtain the same Span instance that the span creation API returned to the user — [L283](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L283)

### Sampling

- [ ] Span Processor MUST receive only spans which have IsRecording set to true — [L304](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L304)
- [ ] Span Exporter SHOULD NOT receive spans unless the Sampled flag was also set — [L305](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L305)
- [ ] Span Exporters MUST receive spans which have Sampled flag set to true — [L310](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L310)
- [ ] Span Exporters SHOULD NOT receive spans that do not have Sampled flag set — [L311](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L311)
- [ ] SDK MUST NOT allow combination of SampledFlag == true and IsRecording == false — [L320](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L320)

### SDK Span Creation

- [ ] When asked to create a Span, the SDK MUST act as if doing the following in order (generate/use trace ID, query sampler, generate span ID, create span) — [L339](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L339)

### Sampler — ShouldSample

- [ ] If parent SpanContext contains a valid TraceId, it MUST always match the TraceId argument — [L380](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L380)
- [ ] RECORD_ONLY decision: Sampled flag MUST NOT be set — [L398](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L398)
- [ ] RECORD_AND_SAMPLE decision: Sampled flag MUST be set — [L399](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L399)
- [ ] Samplers SHOULD normally return the passed-in Tracestate if they do not intend to change it — [L405](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L405)

### Sampler — GetDescription

- [ ] Callers SHOULD NOT cache the returned value of GetDescription — [L416](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L416)

### Built-in Samplers — AlwaysOn

- [ ] Description MUST be `AlwaysOnSampler` — [L426](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L426)

### Built-in Samplers — AlwaysOff

- [ ] Description MUST be `AlwaysOffSampler` — [L431](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L431)

### Built-in Samplers — TraceIdRatioBased

- [ ] TraceIdRatioBased MUST ignore the parent SampledFlag — [L447](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L447)
- [ ] Description MUST return a string of the form `"TraceIdRatioBased{RATIO}"` — [L450](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L450)
- [ ] Description precision SHOULD be high enough to identify different ratios — [L453](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L453)
- [ ] Sampling algorithm MUST be deterministic (deterministic hash of TraceId) — [L462](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L462)
- [ ] A TraceIdRatioBased sampler with a given probability MUST also sample all traces that a lower probability sampler would sample — [L467](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L467)

### Span Limits

- [ ] Span attributes MUST adhere to the common rules of attribute limits — [L836](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L836)
- [ ] If SDK implements span limits, it MUST provide a way to change these limits via TracerProvider configuration — [L841](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L841)
- [ ] The name of the configuration options SHOULD be EventCountLimit and LinkCountLimit — [L845](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L845)
- [ ] Options class SHOULD be called SpanLimits — [L846](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L846)
- [ ] There SHOULD be a message printed in the SDK's log when attribute/event/link is discarded due to limit — [L873](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L873)
- [ ] Discard message MUST be printed at most once per span — [L875](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L875)

### Id Generators

- [ ] SDK MUST by default randomly generate both the TraceId and the SpanId — [L880](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L880)
- [ ] SDK MUST provide a mechanism for customizing the way IDs are generated — [L882](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L882)
- [ ] Method names MUST be consistent with SpanContext (retrieving TraceId and SpanId) — [L887](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L887)
- [ ] Additional IdGenerator for vendor-specific protocols MUST NOT be maintained in Core OpenTelemetry repositories — [L899](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L899)

### Span Processor — Interface Definition

- [ ] SpanProcessor interface MUST declare OnStart, OnEnd, Shutdown, and ForceFlush methods — [L952](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L952)
- [ ] SpanProcessor interface SHOULD declare OnEnding method — [L959](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L959)

### Span Processor — OnStart

- [ ] OnStart `span` parameter: it SHOULD be possible to keep a reference to the span object and updates SHOULD be reflected in it — [L973](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L973)

### Span Processor — OnEnd

- [ ] OnEnd MUST be called synchronously within the Span.End() API — [L1008](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1008)

### Span Processor — Shutdown

- [ ] Shutdown SHOULD be called only once for each SpanProcessor instance — [L1024](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1024)
- [ ] After Shutdown, SDKs SHOULD ignore subsequent calls to OnStart, OnEnd, or ForceFlush gracefully — [L1026](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1026)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1028](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1028)
- [ ] Shutdown MUST include the effects of ForceFlush — [L1031](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1031)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L1033](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1033)

### Span Processor — ForceFlush

- [ ] SpanProcessor ForceFlush: tasks for already-received Spans SHOULD be completed as soon as possible — [L1041](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1041)
- [ ] If SpanProcessor has an associated exporter, it SHOULD try to call Export and then ForceFlush on it — [L1044](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1044)
- [ ] Built-in SpanProcessors MUST call Export and ForceFlush on their exporter — [L1047](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1047)
- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1052](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1052)
- [ ] ForceFlush SHOULD only be called in cases where absolutely necessary — [L1055](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1055)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L1059](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1059)

### Built-in Span Processors

- [ ] Standard SDK MUST implement both simple and batch processors — [L1066](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1066)

### Built-in Span Processors — Simple Processor

- [ ] Simple processor MUST synchronize calls to Span Exporter's Export to avoid concurrent invocations — [L1076](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1076)

### Built-in Span Processors — Batching Processor

- [ ] Batching processor MUST synchronize calls to Span Exporter's Export to avoid concurrent invocations — [L1089](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1089)
- [ ] Processor SHOULD export a batch when scheduledDelay expires, queue reaches maxExportBatchSize, or ForceFlush is called — [L1092](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1092)

### Span Exporter — Interface Definition

- [ ] Each exporter implementation MUST document the concurrency characteristics the SDK requires — [L1130](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1130)
- [ ] Exporter MUST support three functions: Export, Shutdown, and ForceFlush — [L1135](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1135)

### Span Exporter — Export

- [ ] Export MUST NOT block indefinitely; there MUST be a reasonable upper limit after which the call times out with Failure — [L1156](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1156)
- [ ] Default SDK's Span Processors SHOULD NOT implement retry logic — [L1160](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1160)

### Span Exporter — ForceFlush

- [ ] Exporter ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1208](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1208)
- [ ] Exporter ForceFlush SHOULD only be called in cases where absolutely necessary — [L1211](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1211)
- [ ] Exporter ForceFlush SHOULD complete or abort within some timeout — [L1215](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1215)

### Concurrency requirements

- [ ] Tracer Provider: Tracer creation, ForceFlush and Shutdown MUST be safe to be called concurrently — [L1281](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1281)
- [ ] Sampler: ShouldSample and GetDescription MUST be safe to be called concurrently — [L1284](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1284)
- [ ] Span processor: all methods MUST be safe to be called concurrently — [L1287](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1287)
- [ ] Span Exporter: ForceFlush and Shutdown MUST be safe to be called concurrently — [L1289](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1289)
