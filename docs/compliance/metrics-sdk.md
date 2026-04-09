# Metrics SDK

> Ref: [metrics/sdk.md](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md)

### General

- [ ] All language implementations of OpenTelemetry MUST provide an SDK — [L103](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L103)

### MeterProvider (Stable)

- [ ] MeterProvider MUST provide a way to allow a Resource to be specified — [L109](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L109)
- [ ] If a Resource is specified, it SHOULD be associated with all metrics produced by any Meter from the MeterProvider — [L110](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L110)

#### MeterProvider Creation

- [ ] SDK SHOULD allow the creation of multiple independent MeterProviders — [L117](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L117)

#### Meter Creation

- [ ] It SHOULD only be possible to create Meter instances through a MeterProvider — [L121](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L121)
- [ ] MeterProvider MUST implement the Get a Meter API — [L124](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L124)
- [ ] The input provided by the user MUST be used to create an InstrumentationScope instance stored on the created Meter — [L126](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L126)
- [ ] In the case where an invalid name is specified, a working Meter MUST be returned as a fallback — [L131](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L131)
- [ ] Invalid name Meter's name SHOULD keep the original invalid value — [L132](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L132)
- [ ] A message reporting that the specified value is invalid SHOULD be logged — [L133](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L133)

#### Configuration

- [ ] Configuration (MetricExporters, MetricReaders, Views) MUST be owned by the MeterProvider — [L144](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L144)
- [ ] If configuration is updated, the updated configuration MUST also apply to all already returned Meters — [L150](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L150)

#### Shutdown

- [ ] Shutdown MUST be called only once for each MeterProvider instance — [L191](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L191)
- [ ] After Shutdown, SDKs SHOULD return a valid no-op Meter for subsequent Get a Meter calls — [L193](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L193)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L196](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L196)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L198](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L198)
- [ ] Shutdown MUST be implemented at least by invoking Shutdown on all registered MetricReaders and MetricExporters — [L203](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L203)

#### ForceFlush

- [ ] ForceFlush MUST invoke ForceFlush on all registered MetricReader instances that implement ForceFlush — [L216](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L216)
- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L219](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L219)
- [ ] ForceFlush SHOULD return ERROR status if there is an error condition — [L220](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L220)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L225](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L225)

### View (Stable)

- [ ] SDK MUST provide functionality for a user to create Views for a MeterProvider — [L252](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L252)
- [ ] View creation MUST accept Instrument selection criteria and the resulting stream configuration — [L253](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L253)
- [ ] SDK MUST provide the means to register Views with a MeterProvider — [L257](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L257)

#### Instrument Selection Criteria

- [ ] Criteria SHOULD be treated as additive — [L264](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L264)
- [ ] SDK MUST accept the `name` criterion — [L270](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L270)
- [ ] If SDK does not support wildcards in general, it MUST still recognize the single asterisk (`*`) as matching all Instruments — [L288](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L288)
- [ ] `name` criterion MUST NOT obligate a user to provide one — [L293](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L293)
- [ ] `type` criterion MUST NOT obligate a user to provide one — [L299](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L299)
- [ ] `unit` criterion MUST NOT obligate a user to provide one — [L305](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L305)
- [ ] `meter_name` criterion MUST NOT obligate a user to provide one — [L311](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L311)
- [ ] `meter_version` criterion MUST NOT obligate a user to provide one — [L316](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L316)
- [ ] `meter_schema_url` criterion MUST NOT obligate a user to provide one — [L323](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L323)
- [ ] Additional criteria MUST NOT obligate a user to provide them — [L331](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L331)

#### Stream Configuration

- [ ] SDK MUST accept `name` stream configuration parameter — [L339](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L339)
- [ ] View with `name` SHOULD have instrument selector that selects at most one instrument — [L343](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L343)
- [ ] Stream configuration `name` MUST NOT obligate a user to provide one — [L352](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L352)
- [ ] If user does not provide a `name`, name from the matching Instrument MUST be used by default — [L353](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L353)
- [ ] Stream configuration `description` SHOULD be used — [L355](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L355)
- [ ] `description` MUST NOT obligate a user to provide one — [L360](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L360)
- [ ] If user does not provide a `description`, description from the matching Instrument MUST be used by default — [L361](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L361)
- [ ] `attribute_keys` allow-list: listed keys MUST be kept, all other attributes MUST be ignored — [L364](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L364)
- [ ] `attribute_keys` MUST NOT obligate a user to provide them — [L372](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L372)
- [ ] If user does not provide `attribute_keys`, SDK SHOULD use the `Attributes` advisory parameter — [L373](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L373)
- [ ] If `Attributes` advisory parameter is absent, all attributes MUST be kept — [L376](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L376)
- [ ] SHOULD support configuring an exclude-list of attribute keys — [L378](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L378)
- [ ] Exclude-list: listed keys MUST be excluded, all other attributes MUST be kept — [L380](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L380)
- [ ] `aggregation` MUST NOT obligate a user to provide one — [L390](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L390)
- [ ] If user does not provide `aggregation`, MeterProvider MUST apply default aggregation configurable per instrument type per MetricReader — [L391](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L391)
- [ ] `exemplar_reservoir` MUST NOT obligate a user to provide one — [L402](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L402)
- [ ] If user does not provide `exemplar_reservoir`, MeterProvider MUST apply a default exemplar reservoir — [L404](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L404)
- [ ] `aggregation_cardinality_limit` MUST NOT obligate a user to provide one — [L412](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L412)
- [ ] If user does not provide `aggregation_cardinality_limit`, MeterProvider MUST apply the default from MetricReader — [L414](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L414)

#### Measurement Processing

- [ ] SDK SHOULD use the specified logic to determine how to process Measurements — [L420](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L420)
- [ ] When no View registered, instrument advisory parameters MUST be honored — [L428](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L428)
- [ ] If applying a View results in conflicting metric identities, SDK SHOULD apply the View and emit a warning — [L439](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L439)
- [ ] If both a View and instrument advisory parameters specify the same aspect, the View MUST take precedence — [L446](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L446)
- [ ] If Instrument could not match any registered Views, SDK SHOULD enable the instrument using default aggregation and temporality — [L448](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L448)

### Aggregation (Stable)

- [ ] SDK MUST provide Drop, Default, Sum, Last Value, Explicit Bucket Histogram aggregations — [L567](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L567)
- [ ] SDK SHOULD provide Base2 Exponential Bucket Histogram aggregation — [L577](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L577)

#### Histogram Aggregations

- [ ] Histogram arithmetic sum SHOULD NOT be collected when used with instruments that record negative measurements — [L646](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L646)

#### Explicit Bucket Histogram Aggregation

- [ ] SDKs SHOULD use the default boundaries when boundaries are not explicitly provided — [L661](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L661)

#### Base2 Exponential Bucket Histogram Aggregation

- [ ] Implementations MUST accept the entire normal range of IEEE floating point values — [L728](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L728)
- [ ] Implementations SHOULD NOT incorporate non-normal values (+Inf, -Inf, NaN) into sum, min, max — [L732](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L732)
- [ ] Implementation MUST maintain reasonable minimum and maximum scale parameters — [L741](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L741)
- [ ] When histogram contains not more than one value, implementation SHOULD use the maximum scale — [L748](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L748)
- [ ] Implementations SHOULD adjust histogram scale to maintain the best resolution possible — [L753](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L753)

### Observations Inside Asynchronous Callbacks (Stable)

- [ ] Callback functions MUST be invoked for the specific MetricReader performing collection — [L762](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L762)
- [ ] Implementation SHOULD disregard async instrument API usage outside of registered callbacks — [L767](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L767)
- [ ] Implementation SHOULD use a timeout to prevent indefinite callback execution — [L770](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L770)
- [ ] Implementation MUST complete execution of all callbacks for a given instrument before starting a subsequent round of collection — [L773](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L773)
- [ ] Implementation SHOULD NOT produce aggregated metric data for a previously-observed attribute set not observed during a successful callback — [L776](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L776)

### Cardinality Limits (Stable)

- [ ] SDKs SHOULD support being configured with a cardinality limit — [L809](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L809)
- [ ] Cardinality limit enforcement SHOULD occur after attribute filtering — [L813](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L813)

#### Configuration

- [ ] If view defines `aggregation_cardinality_limit`, that value SHOULD be used — [L823](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L823)
- [ ] If no matching view but MetricReader defines a default cardinality limit, that value SHOULD be used — [L826](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L826)
- [ ] If no values defined, the default value of 2000 SHOULD be used — [L827](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L827)

#### Overflow Attribute

- [ ] SDK MUST create an Aggregator with the overflow attribute set prior to reaching the cardinality limit — [L837](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L837)
- [ ] SDK MUST provide the guarantee that overflow would not happen if max distinct non-overflow attribute sets is less than or equal to the limit — [L840](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L840)

#### Synchronous Instrument Cardinality Limits

- [ ] Aggregators for synchronous instruments with cumulative temporality MUST continue to export all attribute sets observed prior to overflow — [L846](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L846)
- [ ] SDK MUST ensure every Measurement is reflected in exactly one Aggregator — [L856](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L856)
- [ ] Measurements MUST NOT be double-counted or dropped during an overflow — [L861](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L861)

#### Asynchronous Instrument Cardinality Limits

- [ ] Aggregators of asynchronous instruments SHOULD prefer the first-observed attributes in the callback when limiting cardinality — [L866](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L866)

### Meter (Stable)

- [ ] Distinct meters MUST be treated as separate namespaces for duplicate instrument registration — [L872](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L872)

#### Duplicate Instrument Registration

- [ ] Meter MUST return a functional instrument even for duplicate instrument registrations — [L912](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L912)
- [ ] When duplicate instrument registration occurs (not corrected with a View), a warning SHOULD be emitted — [L919](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L919)
- [ ] Warning SHOULD include information on how to resolve the conflict — [L919](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L919)
- [ ] If conflict involves multiple `description` properties, setting description through a View SHOULD avoid the warning — [L923](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L923)
- [ ] If conflict involves instruments distinguishable by a supported View selector, a renaming View recipe SHOULD be included — [L926](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L926)
- [ ] Otherwise, SDK SHOULD pass through data reporting both Metric objects and emit a generic warning — [L928](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L928)
- [ ] SDK MUST aggregate data from identical Instruments together in its export pipeline — [L942](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L942)

#### Name Conflict

- [ ] When duplicate case-insensitive names occur, Meter MUST return an instrument using the first-seen name and log an error — [L950](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L950)

### Instrument Name

- [ ] Meter SHOULD validate instrument name conforms to syntax — [L962](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L962)
- [ ] If instrument name does not conform, Meter SHOULD emit an error — [L965](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L965)

### Instrument Unit

- [ ] Meter SHOULD NOT validate instrument unit — [L971](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L971)
- [ ] If a unit is not provided or is null, Meter MUST treat it as an empty unit string — [L972](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L972)

### Instrument Description

- [ ] Meter SHOULD NOT validate instrument description — [L977](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L977)
- [ ] If description is not provided or is null, Meter MUST treat it as an empty description string — [L979](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L979)

### Instrument Advisory Parameters (Stable)

- [ ] Meter SHOULD validate instrument advisory parameters — [L985](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L985)
- [ ] If advisory parameter is not valid, Meter SHOULD emit an error and proceed as if the parameter was not provided — [L986](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L986)
- [ ] If multiple identical Instruments have different advisory parameters, Meter MUST return instrument using first-seen advisory parameters and log an error — [L990](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L990)
- [ ] If View and advisory parameters specify the same aspect, View MUST take precedence — [L996](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L996)

#### ExplicitBucketBoundaries Advisory Parameter

- [ ] If no View matches or default aggregation is selected, the ExplicitBucketBoundaries advisory parameter MUST be used — [L1009](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1009)

### Instrument Enabled

- [ ] Synchronous instrument Enabled MUST return false when all resolved views are configured with Drop Aggregation — [L1029](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1029)
- [ ] Otherwise, it SHOULD return true — [L1037](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1037)

### Exemplar (Stable)

- [ ] Metric SDK MUST provide a mechanism to sample Exemplars from measurements via ExemplarFilter and ExemplarReservoir hooks — [L1100](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1100)
- [ ] Exemplar sampling SHOULD be turned on by default — [L1103](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1103)
- [ ] If Exemplar sampling is off, SDK MUST NOT have overhead related to exemplar sampling — [L1104](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1104)
- [ ] Metric SDK MUST allow exemplar sampling to leverage the configuration of metric aggregation — [L1106](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1106)
- [ ] Metric SDK SHOULD provide configuration for Exemplar sampling (ExemplarFilter, ExemplarReservoir) — [L1110](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1110)

#### ExemplarFilter

- [ ] ExemplarFilter configuration MUST allow users to select between built-in ExemplarFilters — [L1117](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1117)
- [ ] ExemplarFilter SHOULD be a configuration parameter of a MeterProvider — [L1122](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1122)
- [ ] Default ExemplarFilter value SHOULD be TraceBased — [L1123](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1123)
- [ ] Filter configuration SHOULD follow the environment variable specification — [L1124](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1124)
- [ ] SDK MUST support AlwaysOn, AlwaysOff, TraceBased filters — [L1126](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1126)

#### ExemplarReservoir

- [ ] ExemplarReservoir interface MUST provide a method to offer measurements and another to collect accumulated Exemplars — [L1148](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1148)
- [ ] A new ExemplarReservoir MUST be created for every known timeseries data point — [L1151](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1151)
- [ ] "offer" method SHOULD accept measurements including value, attributes, context, timestamp — [L1155](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1155)
- [ ] "offer" method SHOULD have ability to pull associated trace/span information without full context — [L1164](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1164)
- [ ] If filtered subset of Attributes is accepted, this MUST be clearly documented and reservoir MUST be given the timeseries Attributes at construction — [L1172](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1172)
- [ ] "collect" method MUST return accumulated Exemplars — [L1179](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1179)
- [ ] Exemplars reported against a metric data point SHOULD have occurred within the start/stop timestamps of that point — [L1181](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1181)
- [ ] Exemplars MUST retain any attributes available in the measurement not preserved by aggregation or view configuration — [L1186](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1186)
- [ ] ExemplarReservoir SHOULD avoid allocations when sampling exemplars — [L1192](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1192)

#### Exemplar Defaults

- [ ] SDK MUST include SimpleFixedSizeExemplarReservoir and AlignedHistogramBucketExemplarReservoir — [L1196](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1196)
- [ ] Explicit bucket histogram with more than 1 bucket SHOULD use AlignedHistogramBucketExemplarReservoir — [L1203](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1203)
- [ ] Base2 Exponential Histogram SHOULD use SimpleFixedSizeExemplarReservoir with reservoir = min(20, max_buckets) — [L1205](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1205)
- [ ] All other aggregations SHOULD use SimpleFixedSizeExemplarReservoir — [L1209](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1209)

#### SimpleFixedSizeExemplarReservoir

- [ ] MUST use uniformly-weighted sampling algorithm based on number of samples seen — [L1218](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1218)
- [ ] Any stateful portion of sampling computation SHOULD be reset every collection cycle — [L1235](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1235)
- [ ] If no size configuration provided, a default size of 1 SHOULD be used — [L1242](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1242)

#### AlignedHistogramBucketExemplarReservoir

- [ ] MUST take a configuration parameter that is the configuration of a Histogram — [L1246](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1246)
- [ ] MUST store at most one measurement per histogram bucket — [L1247](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1247)
- [ ] SHOULD use uniformly-weighted sampling to determine if offered measurements should be sampled — [L1248](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1248)
- [ ] Configuration parameter for bucket boundaries SHOULD have the same format as specifying Explicit Bucket Histogram boundaries — [L1276](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1276)

#### Custom ExemplarReservoir

- [ ] SDK MUST provide a mechanism for SDK users to provide their own ExemplarReservoir implementation — [L1282](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1282)
- [ ] Extension MUST be configurable on a metric View — [L1283](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1283)
- [ ] Individual reservoirs MUST still be instantiated per metric-timeseries — [L1284](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1284)

### MetricReader (Stable)

- [ ] MetricReader construction SHOULD be provided with an exporter — [L1302](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1302)
- [ ] Default output aggregation function SHOULD be obtained from the exporter; if not configured, default aggregation SHOULD be used — [L1305](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1305)
- [ ] Output temporality function SHOULD be obtained from the exporter; if not configured, Cumulative temporality SHOULD be used — [L1306](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1306)
- [ ] Default cardinality limit, if not configured, a default value of 2000 SHOULD be used — [L1307](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1307)
- [ ] A common implementation, periodic exporting MetricReader, SHOULD be provided — [L1318](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1318)
- [ ] MetricReader MUST ensure data points from OTel instruments are output in the configured aggregation temporality — [L1321](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1321)
- [ ] For synchronous instruments with Cumulative temporality, Collect MUST receive data points exposed in previous collections — [L1339](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1339)
- [ ] For synchronous instruments with Delta temporality, Collect MUST only receive data points with measurements recorded since the previous collection — [L1342](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1342)
- [ ] For asynchronous instruments with Delta or Cumulative temporality, Collect MUST only receive data points with measurements recorded since previous collection — [L1345](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1345)
- [ ] For Cumulative temporality, successive data points MUST repeat the same starting timestamps — [L1354](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1354)
- [ ] For Delta temporality, successive data points MUST advance the starting timestamp — [L1357](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1357)
- [ ] Ending timestamp MUST always be equal to time the metric data point took effect (when Collect was invoked) — [L1359](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1359)
- [ ] SDK MUST support multiple MetricReader instances on the same MeterProvider — [L1365](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1365)
- [ ] Collect on one MetricReader SHOULD NOT introduce side-effects to other MetricReader instances — [L1367](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1367)
- [ ] SDK MUST NOT allow a MetricReader instance to be registered on more than one MeterProvider — [L1374](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1374)
- [ ] SDK SHOULD provide a way to allow MetricReader to respond to ForceFlush and Shutdown — [L1391](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1391)

#### Collect

- [ ] Collect SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1406](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1406)
- [ ] Collect SHOULD invoke Produce on registered MetricProducers — [L1416](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1416)

#### Shutdown

- [ ] Shutdown MUST be called only once for each MetricReader instance — [L1430](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1430)
- [ ] After Shutdown, subsequent Collect invocations are not allowed; SDKs SHOULD return failure — [L1431](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1431)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1434](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1434)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L1437](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1437)

### Periodic Exporting MetricReader

- [ ] Reader MUST synchronize calls to MetricExporter's Export to make sure they are not invoked concurrently — [L1455](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1455)

#### ForceFlush (Periodic)

- [ ] ForceFlush SHOULD collect metrics, call Export(batch) and ForceFlush() on the configured Push Metric Exporter — [L1478](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1478)
- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1482](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1482)
- [ ] ForceFlush SHOULD return ERROR status if there is an error condition — [L1483](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1483)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L1488](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1488)

### MetricExporter (Stable)

- [ ] MetricExporter defines the interface that protocol-specific exporters MUST implement — [L1496](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1496)
- [ ] Metric Exporters SHOULD report an error for unsupported Aggregation or Aggregation Temporality — [L1512](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1512)

#### Push Metric Exporter

- [ ] Push Metric Exporter MUST support Export(batch), ForceFlush, Shutdown functions — [L1557](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1557)

##### Export(batch)

- [ ] SDK MUST provide a way for exporter to get Meter information associated with each Metric Point — [L1565](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1565)
- [ ] Export MUST NOT block indefinitely; there MUST be a reasonable upper limit timeout — [L1571](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1571)
- [ ] Default SDK SHOULD NOT implement retry logic — [L1575](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1575)

##### ForceFlush (Exporter)

- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1629](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1629)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L1636](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1636)

##### Shutdown (Exporter)

- [ ] Shutdown SHOULD be called only once for each MetricExporter instance — [L1646](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1646)
- [ ] After Shutdown, subsequent Export calls should return Failure — [L1647](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1647)
- [ ] Shutdown SHOULD NOT block indefinitely — [L1650](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1650)

### MetricProducer (Stable)

- [ ] MetricProducer defines the interface which bridges to third-party metric sources MUST implement — [L1707](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1707)
- [ ] MetricProducer implementations SHOULD accept configuration for AggregationTemporality — [L1711](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1711)
- [ ] MetricProducer MUST support the Produce function — [L1735](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1735)
- [ ] Produce MUST return a batch of Metric Points — [L1740](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1740)
- [ ] If batch includes resource information, Produce SHOULD require a resource as a parameter — [L1746](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1746)
- [ ] Produce SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1751](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1751)
- [ ] If batch can include InstrumentationScope, Produce SHOULD include a single InstrumentationScope identifying the MetricProducer — [L1758](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1758)

### Defaults and Configuration

- [ ] SDK MUST provide configuration according to the SDK environment variables specification — [L1837](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1837)

### Numerical Limits Handling

- [ ] SDK MUST handle numerical limits in a graceful way — [L1842](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1842)
- [ ] If SDK receives float/double values, it MUST handle all possible values (e.g. NaN, Infinities) — [L1845](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1845)

### Compatibility Requirements (Stable)

- [ ] All metrics components SHOULD allow new methods to be added without introducing breaking changes — [L1862](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1862)
- [ ] All metrics SDK methods SHOULD allow optional parameters to be added without introducing breaking changes — [L1865](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1865)

### Concurrency Requirements (Stable)

- [ ] MeterProvider: Meter creation, ForceFlush, and Shutdown MUST be safe to be called concurrently — [L1875](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1875)
- [ ] ExemplarReservoir: all methods MUST be safe to be called concurrently — [L1878](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1878)
- [ ] MetricReader: Collect, ForceFlush, and Shutdown MUST be safe to be called concurrently — [L1880](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1880)
- [ ] MetricExporter: ForceFlush and Shutdown MUST be safe to be called concurrently — [L1883](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1883)

---
