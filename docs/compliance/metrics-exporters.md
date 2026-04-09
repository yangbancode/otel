# Metrics Exporters

### Console (stdout)

> Ref: [metrics/sdk_exporters/stdout.md](../references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md)

- [ ] Documentation SHOULD warn users about unspecified output format — [L14](../references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L14)
- [ ] Stdout Metrics Exporter MUST provide configuration to set MetricReader output temporality as a function of instrument kind — [L30](../references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L30)
- [ ] Temporality option MUST set temporality to Cumulative for all instrument kinds by default — [L33](../references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L33)
- [ ] If default_aggregation is provided, it MUST use the default aggregation by default — [L37](../references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L37)
- [ ] If auto-configuration mechanism is provided, exporter MUST be paired with a periodic exporting MetricReader with default exportIntervalMilliseconds of 10000 — [L44](../references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L44)
