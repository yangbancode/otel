# Metrics

## Quick start

```elixir
# mix.exs — SDK auto-starts with OTLP HTTP exporter at localhost:4318
{:otel, "~> 0.1"}
```

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app"}
meter = Otel.API.Metrics.MeterProvider.get_meter(scope)

counter = Otel.API.Metrics.Meter.create_counter(meter, "http.requests")
Otel.API.Metrics.Counter.add(counter, 1, %{"http.method" => "GET"})
```

See [Configuration](configuration.md) for endpoint, export interval,
views, exemplar filter, etc.

## Pick an instrument

| Instrument | Use when | Example |
|---|---|---|
| **Counter** | value only goes up | `http.server.requests`, `db.queries` |
| **UpDownCounter** | value goes up and down | `queue.depth`, `connections.active` |
| **Histogram** | distribution of values | `http.server.duration`, `db.query.duration` |
| **Gauge** (sync) | current value, sample inline | `cpu.temperature` |
| **ObservableCounter** | counter measured on demand | `process.runtime.uptime` |
| **ObservableUpDownCounter** | up-down via callback | `process.runtime.memory` |
| **ObservableGauge** | current value, callback-driven | `system.memory.usage` |

Sync instruments report each measurement immediately. Async
(observable) instruments register a callback that the SDK invokes at
each collection cycle to *pull* the current value (default 60s
interval).

## Get a meter

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
meter = Otel.API.Metrics.MeterProvider.get_meter(scope)
```

## Synchronous instruments

### Counter

```elixir
counter = Otel.API.Metrics.Meter.create_counter(meter, "http.requests",
  unit: "1",
  description: "Number of HTTP requests"
)

Otel.API.Metrics.Counter.add(counter, 1, %{
  "http.method" => "GET",
  "http.status_code" => 200
})
```

### UpDownCounter

```elixir
gauge_like = Otel.API.Metrics.Meter.create_updown_counter(meter, "queue.depth",
  unit: "1"
)

Otel.API.Metrics.UpDownCounter.add(gauge_like, 1, %{"queue" => "ingest"})
Otel.API.Metrics.UpDownCounter.add(gauge_like, -1, %{"queue" => "ingest"})
```

### Histogram

```elixir
duration = Otel.API.Metrics.Meter.create_histogram(meter, "http.server.duration",
  unit: "ms",
  description: "HTTP server request duration"
)

Otel.API.Metrics.Histogram.record(duration, 47, %{"http.route" => "/orders/:id"})
```

Custom bucket boundaries:

```elixir
Otel.API.Metrics.Meter.create_histogram(meter, "http.server.duration",
  unit: "ms",
  advisory: [explicit_bucket_boundaries: [10, 50, 100, 500, 1000]]
)
```

### Gauge

```elixir
temperature = Otel.API.Metrics.Meter.create_gauge(meter, "cpu.temperature",
  unit: "Cel"
)

Otel.API.Metrics.Gauge.record(temperature, 67.5, %{"core" => "0"})
```

## Asynchronous (observable) instruments

The callback returns a list of `%Measurement{}`, one per attribute set.
The SDK invokes it at each collection cycle.

### ObservableCounter

```elixir
Otel.API.Metrics.Meter.create_observable_counter(
  meter,
  "process.runtime.uptime",
  fn _args ->
    {wall_clock_ms, _} = :erlang.statistics(:wall_clock)
    [%Otel.API.Metrics.Measurement{value: div(wall_clock_ms, 1000), attributes: %{}}]
  end,
  nil,
  unit: "s"
)
```

### ObservableUpDownCounter

```elixir
Otel.API.Metrics.Meter.create_observable_updown_counter(
  meter,
  "process.runtime.memory",
  fn _args ->
    info = :erlang.memory()

    [
      %Otel.API.Metrics.Measurement{value: info[:total], attributes: %{"type" => "total"}},
      %Otel.API.Metrics.Measurement{value: info[:processes], attributes: %{"type" => "processes"}}
    ]
  end,
  nil,
  unit: "By"
)
```

### ObservableGauge

```elixir
Otel.API.Metrics.Meter.create_observable_gauge(
  meter,
  "queue.depth",
  fn _args ->
    [%Otel.API.Metrics.Measurement{value: MyApp.Queue.size(), attributes: %{}}]
  end,
  nil,
  unit: "1"
)
```

The 4th argument (`nil` above) is `callback_args` — passed back into
the callback. Useful when one callback feeds multiple instruments via
`Meter.register_callback/5`.

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
Otel.API.Metrics.Counter.add(counter, 1, %{
  "http.method" => "GET",
  "http.status_code" => 200,
  "http.route" => "/orders/:id"
})
```

### Cardinality limit

Each unique attribute set creates a separate time series. The SDK caps
this at 2000 per instrument; the (2001)st onward folds into a single
`otel.metric.overflow=true` series so a runaway label doesn't kill the
backend. Adjust per-View:

```elixir
%Otel.SDK.Metrics.View{
  criteria: %{name: "http.requests"},
  config: %{aggregation_cardinality_limit: 500}
}
```

## Views

A View customises how the SDK aggregates a stream of measurements
*after* the instrument is created.

### Rename an instrument

```elixir
%Otel.SDK.Metrics.View{
  criteria: %{name: "old.name"},
  config: %{name: "new.name"}
}
```

### Filter attribute keys

Drop unwanted high-cardinality labels:

```elixir
%Otel.SDK.Metrics.View{
  criteria: %{name: "http.requests"},
  config: %{attribute_keys: {:include, ["http.method", "http.status_code"]}}
}
```

### Override aggregation

Promote a Counter to a Histogram, or swap to base-2 exponential
buckets:

```elixir
%Otel.SDK.Metrics.View{
  criteria: %{name: "queue.latency"},
  config: %{aggregation: Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram}
}
```

### Drop

Suppress the instrument entirely (zero application cost):

```elixir
%Otel.SDK.Metrics.View{
  criteria: %{name: "noisy.metric"},
  config: %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
}
```

Wire Views via `config :otel, metrics: [views: [...]]` or
programmatically:

```elixir
Otel.SDK.Metrics.MeterProvider.add_view(
  Otel.SDK.Metrics.MeterProvider,
  %{name: "queue.latency"},
  %{aggregation: Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram}
)
```

## Temporality

Default `:cumulative` — counters report running totals. Switch a reader
to `:delta` per kind:

```elixir
config :otel,
  metrics: [
    readers: [
      {Otel.SDK.Metrics.MetricReader.PeriodicExporting,
        %{
          exporter: {Otel.OTLP.Metrics.MetricExporter.HTTP, %{}},
          temporality_mapping: %{counter: :delta}
        }}
    ]
  ]
```

Most Prometheus-derived backends (Mimir, Cortex) expect cumulative;
delta works with backends that explicitly support delta-to-cumulative
conversion.

## Exemplars

Histograms and counters can attach trace exemplars (a sampled
`trace_id` linked to the measurement). Default filter is
`:trace_based` — only sampled spans contribute exemplars.

```elixir
config :otel, metrics: [exemplar_filter: :always_on]    # every measurement
config :otel, metrics: [exemplar_filter: :always_off]   # none
```

## Limits

See [Configuration](configuration.md) §"Metrics pillar" for export
interval, export timeout, exemplar filter, and other knobs.
