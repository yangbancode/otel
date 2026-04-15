# MetricExporter & MetricProducer

## Question

How to implement MetricExporter (Push) and MetricProducer (third-party bridge) interfaces on BEAM?

## Decision

### MetricExporter Behaviour

`Otel.SDK.Metrics.MetricExporter` defines callbacks:
- `init(config)` — `{:ok, state}` or `:ignore`
- `export(metrics, state)` — `:ok` or `:error`
- `force_flush(state)` — `:ok`
- `shutdown(state)` — `:ok`

Export is called by MetricReader (serialized, not concurrent).

### Console MetricExporter

`Otel.SDK.Metrics.Exporter.Console` — outputs metrics to stdout
in human-readable format. Formats counters/gauges as simple values,
histograms with count, sum, min, max, and bucket counts.

Follows the same pattern as `Otel.SDK.Trace.Exporter.Console`.

### MetricProducer Behaviour

`Otel.SDK.Metrics.MetricProducer` bridges third-party metric
sources. Single callback:
- `produce(config)` — `{:ok, [metric()]}` or `{:error, term()}`

MetricProducers are registered with a MetricReader. The reader
calls produce during collection alongside SDK metrics.

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Metrics.MetricExporter` | `metric_exporter.ex` | Push exporter behaviour |
| `Otel.SDK.Metrics.Exporter.Console` | `exporter/console.ex` | Console exporter |
| `Otel.SDK.Metrics.MetricProducer` | `metric_producer.ex` | Third-party bridge behaviour |

## Compliance

- [Metrics SDK](../compliance.md)
  * MetricExporter (Stable) — L1496, L1512
  * Push Metric Exporter — L1557, L1565, L1571, L1575, L1629, L1636, L1646, L1647, L1650
  * MetricProducer (Stable) — L1707, L1711, L1735, L1740, L1746, L1751, L1758
