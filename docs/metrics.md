# Metrics

## Quick start

```elixir
# mix.exs — SDK auto-starts with OTLP HTTP exporter at localhost:4318
{:otel, "~> 0.1"}
```

```elixir
counter = Otel.Metrics.Counter.create("http.requests")
Otel.Metrics.Counter.add(counter, 1, %{"http.method" => "GET"})
```

See [Configuration](configuration.md) for endpoint, export interval,
readers, exemplar filter, etc.

## Pick an instrument

| Instrument | Use when | Example |
|---|---|---|
| **Counter** | value only goes up | `http.server.requests`, `db.queries` |
| **UpDownCounter** | value goes up and down | `queue.depth`, `connections.active` |
| **Histogram** | distribution of values | `http.server.duration`, `db.query.duration` |
| **Gauge** | current value, sample inline | `cpu.temperature` |

All four instruments are synchronous — each measurement is reported
immediately. For poll-based measurements (system metrics, BEAM stats,
queue lengths read on a timer) use the BEAM-native
[`:telemetry`](https://hex.pm/packages/telemetry) ecosystem; a
telemetry-handler bridge for OTel is planned.

## Instruments

### Counter

```elixir
counter = Otel.Metrics.Counter.create("http.requests",
  unit: "1",
  description: "Number of HTTP requests"
)

Otel.Metrics.Counter.add(counter, 1, %{
  "http.method" => "GET",
  "http.status_code" => 200
})
```

### UpDownCounter

```elixir
gauge_like = Otel.Metrics.UpDownCounter.create("queue.depth",
  unit: "1"
)

Otel.Metrics.UpDownCounter.add(gauge_like, 1, %{"queue" => "ingest"})
Otel.Metrics.UpDownCounter.add(gauge_like, -1, %{"queue" => "ingest"})
```

### Histogram

```elixir
duration = Otel.Metrics.Histogram.create("http.server.duration",
  unit: "ms",
  description: "HTTP server request duration"
)

Otel.Metrics.Histogram.record(duration, 47, %{"http.route" => "/orders/:id"})
```

Custom bucket boundaries:

```elixir
Otel.Metrics.Histogram.create("http.server.duration",
  unit: "ms",
  advisory: [explicit_bucket_boundaries: [10, 50, 100, 500, 1000]]
)
```

### Gauge

```elixir
temperature = Otel.Metrics.Gauge.create("cpu.temperature",
  unit: "Cel"
)

Otel.Metrics.Gauge.record(temperature, 67.5, %{"core" => "0"})
```

## Units

`unit:` follows [UCUM](https://ucum.org). Common values:

| Unit | Meaning |
|---|---|
| `"1"` | dimensionless count |
| `"s"`, `"ms"`, `"us"`, `"ns"` | seconds / milliseconds / microseconds / nanoseconds |
| `"By"`, `"KiBy"`, `"MiBy"`, `"GiBy"` | bytes / KiB / MiB / GiB |
| `"Cel"` | degrees Celsius |
| `"%"` | percent |

## Attributes

Every `add/3` / `record/3` / `Measurement{}` accepts an attribute map.

```elixir
Otel.Metrics.Counter.add(counter, 1, %{
  "http.method" => "GET",
  "http.status_code" => 200,
  "http.route" => "/orders/:id"
})
```

### Cardinality limit

Each unique attribute set creates a separate time series. The SDK caps
this at 2000 per instrument; the (2001)st onward folds into a single
`otel.metric.overflow=true` series so a runaway label doesn't kill the
backend. Keep cardinality low at the call site — the SDK ships no
View-based filter to drop attributes after the fact.

## Temporality

Default `:cumulative` — counters report running totals. Most
Prometheus-derived backends (Mimir, Cortex) expect cumulative; delta
requires backends that support delta-to-cumulative conversion. Override
via the advanced reader override; see
[Configuration](configuration.md) §"Advanced overrides".

## Exemplars

Histograms and counters can attach trace exemplars (a sampled
`trace_id` linked to the measurement). Filter is hardcoded to
`:trace_based` — only sampled spans contribute exemplars.

## Defaults

Export interval / timeout / exemplar filter are all hardcoded to
spec defaults. See [Configuration](configuration.md) §"Metrics pillar"
for the full list.
