# Metrics API

> Ref: [metrics/api.md](../references/opentelemetry-specification/v1.55.0/metrics/api.md)

### MeterProvider

- [ ] API SHOULD provide a way to set/register and access a global default MeterProvider — [L111](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L111)
- [ ] MeterProvider MUST provide the function: Get a Meter — [L116](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L116)

### Get a Meter

- [ ] Get a Meter API MUST accept `name` parameter — [L122](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L122)
- [ ] Get a Meter API MUST NOT obligate a user to provide `version` — [L138](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L138)
- [ ] Get a Meter API MUST NOT obligate a user to provide `schema_url` — [L144](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L144)
- [ ] Get a Meter API MUST be structured to accept a variable number of `attributes`, including none — [L150](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L150)

### Meter

- [ ] Meter SHOULD NOT be responsible for the configuration — [L161](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L161)
- [ ] Meter MUST provide functions to create new Instruments (Counter, Async Counter, Histogram, Gauge, Async Gauge, UpDownCounter, Async UpDownCounter) — [L166](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L166)

### Instrument

- [ ] Language-level features such as integer vs floating point SHOULD be considered as identifying — [L194](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L194)

### Instrument unit

- [ ] Unit MUST be case-sensitive, ASCII string — [L225](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L225)
- [ ] API SHOULD treat unit as an opaque string — [L223](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L223)

### Instrument description

- [ ] API MUST treat description as an opaque string — [L235](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L235)
- [ ] Description MUST support BMP (Unicode Plane 0) — [L237](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L237)
- [ ] Description MUST support at least 1023 characters — [L242](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L242)

### Instrument advisory parameters (Mixed top-level, sub-sections checked individually)

#### ExplicitBucketBoundaries (Stable)

- [ ] OpenTelemetry SDKs MUST handle advisory parameters as described in sdk.md — [L254](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L254)

### Synchronous Instrument API

- [ ] API to construct synchronous instruments MUST accept `name` parameter — [L304](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L304)
- [ ] API SHOULD be structured so a user is obligated to provide `name` — [L308](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L308)
- [ ] If not structurally enforced, API MUST be documented to communicate `name` is needed — [L310](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L310)
- [ ] API SHOULD be documented that `name` needs to conform to instrument name syntax — [L313](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L313)
- [ ] API SHOULD NOT validate the `name` — [L315](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L315)
- [ ] API MUST NOT obligate a user to provide `unit` — [L320](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L320)
- [ ] API MUST accept a case-sensitive string for `unit` that supports ASCII and at least 63 characters — [L324](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L324)
- [ ] API SHOULD NOT validate the `unit` — [L326](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L326)
- [ ] API MUST NOT obligate a user to provide `description` — [L331](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L331)
- [ ] API MUST accept a string for `description` that supports BMP and at least 1023 characters — [L334](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L334)
- [ ] API MUST NOT obligate the user to provide `advisory` parameters — [L343](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L343)
- [ ] API SHOULD NOT validate `advisory` parameters — [L348](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L348)

### Asynchronous Instrument API

- [ ] API to construct asynchronous instruments MUST accept `name` parameter — [L357](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L357)
- [ ] API SHOULD be structured so a user is obligated to provide `name` — [L361](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L361)
- [ ] If not structurally enforced, API MUST be documented to communicate `name` is needed — [L363](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L363)
- [ ] API SHOULD be documented that `name` needs to conform to instrument name syntax — [L366](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L366)
- [ ] API SHOULD NOT validate the `name` — [L368](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L368)
- [ ] API MUST NOT obligate a user to provide `unit` — [L373](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L373)
- [ ] API MUST accept a case-sensitive string for `unit` that supports ASCII and at least 63 characters — [L377](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L377)
- [ ] API SHOULD NOT validate the `unit` — [L379](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L379)
- [ ] API MUST NOT obligate a user to provide `description` — [L383](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L383)
- [ ] API MUST accept a string for `description` that supports BMP and at least 1023 characters — [L387](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L387)
- [ ] API MUST NOT obligate the user to provide `advisory` parameters — [L395](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L395)
- [ ] API SHOULD NOT validate `advisory` parameters — [L400](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L400)
- [ ] API MUST be structured to accept a variable number of `callback` functions, including none — [L405](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L405)
- [ ] API MUST support creation of asynchronous instruments by passing zero or more callbacks — [L408](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L408)
- [ ] API SHOULD support registration of callback functions after instrument creation — [L415](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L415)
- [ ] User MUST be able to undo registration of a specific callback after registration — [L419](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L419)
- [ ] Every registered Callback MUST be evaluated exactly once during collection prior to reading data — [L422](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L422)
- [ ] Callback functions MUST be documented: SHOULD be reentrant safe — [L428](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L428)
- [ ] Callback functions MUST be documented: SHOULD NOT take indefinite time — [L430](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L430)
- [ ] Callback functions MUST be documented: SHOULD NOT make duplicate observations — [L431](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L431)
- [ ] Callbacks registered at instrument creation MUST apply to the single instrument under construction — [L446](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L446)
- [ ] Idiomatic APIs for multiple-instrument Callbacks MUST distinguish the instrument associated with each Measurement — [L452](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L452)
- [ ] Multiple-instrument Callbacks MUST be associated with a declared set of async instruments from the same Meter — [L455](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L455)
- [ ] API MUST treat observations from a single Callback as logically at a single instant with identical timestamps — [L462](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L462)
- [ ] API SHOULD provide some way to pass `state` to the callback — [L467](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L467)

### General operations (Enabled)

- [ ] All synchronous instruments SHOULD provide function to report if instrument is Enabled — [L475](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L475)
- [ ] Enabled API MUST be structured in a way for parameters to be added — [L487](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L487)
- [ ] Enabled API MUST return a language idiomatic boolean type — [L489](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L489)
- [ ] Enabled API SHOULD be documented that authors need to call it each time they record a measurement — [L494](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L494)

### Counter

- [ ] There MUST NOT be any API for creating a Counter other than with a Meter — [L512](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L512)

#### Counter Add

- [ ] Add API SHOULD NOT return a value — [L549](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L549)
- [ ] Add API MUST accept a numeric increment value — [L552](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L552)
- [ ] Add API SHOULD be structured so user is obligated to provide increment value — [L557](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L557)
- [ ] If not structurally enforced, Add API MUST be documented to communicate increment is needed — [L558](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L558)
- [ ] Increment value SHOULD be documented as expected to be non-negative — [L562](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L562)
- [ ] Add API SHOULD NOT validate increment value — [L563](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L563)
- [ ] Add API MUST be structured to accept a variable number of attributes, including none — [L569](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L569)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L577](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L577)

### Asynchronous Counter

- [ ] There MUST NOT be any API for creating an Async Counter other than with a Meter — [L615](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L615)
- [ ] API MUST treat observations from a single callback as logically at a single instant with identical timestamps — [L652](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L652)
- [ ] API SHOULD provide some way to pass `state` to the callback — [L655](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L655)

### Histogram

- [ ] There MUST NOT be any API for creating a Histogram other than with a Meter — [L748](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L748)

#### Histogram Record

- [ ] Record API SHOULD NOT return a value — [L785](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L785)
- [ ] Record API MUST accept a numeric value to record — [L788](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L788)
- [ ] Record API SHOULD be structured so user is obligated to provide value — [L792](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L792)
- [ ] If not structurally enforced, Record API MUST be documented to communicate value is needed — [L794](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L794)
- [ ] Record value SHOULD be documented as expected to be non-negative — [L797](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L797)
- [ ] Record API SHOULD NOT validate value — [L799](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L799)
- [ ] Record API MUST be structured to accept a variable number of attributes, including none — [L804](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L804)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L902](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L902)

### Gauge

- [ ] There MUST NOT be any API for creating a Gauge other than with a Meter — [L854](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L854)

#### Gauge Record

- [ ] Record API SHOULD NOT return a value — [L880](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L880)
- [ ] Record API MUST accept a numeric value (current absolute value) — [L883](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L883)
- [ ] Record API SHOULD be structured so user is obligated to provide value — [L888](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L888)
- [ ] If not structurally enforced, Record API MUST be documented to communicate value is needed — [L889](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L889)
- [ ] Record API MUST be structured to accept a variable number of attributes, including none — [L894](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L894)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L902](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L902)

### Asynchronous Gauge

- [ ] There MUST NOT be any API for creating an Async Gauge other than with a Meter — [L936](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L936)

### UpDownCounter

- [ ] There MUST NOT be any API for creating an UpDownCounter other than with a Meter — [L1086](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1086)

#### UpDownCounter Add

- [ ] Add API SHOULD NOT return a value — [L1122](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1122)
- [ ] Add API MUST accept a numeric value to add — [L1125](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1125)
- [ ] Add API SHOULD be structured so user is obligated to provide value — [L1129](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1129)
- [ ] If not structurally enforced, Add API MUST be documented to communicate value is needed — [L1131](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1131)
- [ ] Add API MUST be structured to accept a variable number of attributes, including none — [L1136](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1136)

### Asynchronous UpDownCounter

- [ ] There MUST NOT be any API for creating an Async UpDownCounter other than with a Meter — [L1178](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1178)

### Measurement

- [ ] Multiple-instrument callbacks API SHOULD accept a callback function and a list of Instruments — [L1294](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1294)

### Compatibility requirements

- [ ] All metrics components SHOULD allow new APIs to be added without breaking changes — [L1334](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1334)
- [ ] All metrics APIs SHOULD allow optional parameters to be added without breaking changes — [L1337](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1337)

### Concurrency requirements

- [ ] MeterProvider: all methods MUST be documented as safe for concurrent use — [L1345](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1345)
- [ ] Meter: all methods MUST be documented as safe for concurrent use — [L1348](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1348)
- [ ] Instrument: all methods MUST be documented as safe for concurrent use — [L1351](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1351)

---
