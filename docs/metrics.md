# Metrics

## Get a meter

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
meter = Otel.API.Metrics.MeterProvider.get_meter(scope)
```

## Synchronous instruments

The application reports each measurement as it happens.

### Counter — monotonic increases

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

### UpDownCounter — increases and decreases

For values that go up and down (queue depth, active connections, …).

```elixir
gauge_like = Otel.API.Metrics.Meter.create_updown_counter(meter, "queue.depth",
  unit: "1"
)

Otel.API.Metrics.UpDownCounter.add(gauge_like, 1, %{"queue" => "ingest"})
Otel.API.Metrics.UpDownCounter.add(gauge_like, -1, %{"queue" => "ingest"})
```

### Histogram — distribution of values

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

### Gauge — last-value sampling

For values that represent a current measurement at a point in time.

```elixir
temperature = Otel.API.Metrics.Meter.create_gauge(meter, "cpu.temperature",
  unit: "Cel"
)

Otel.API.Metrics.Gauge.record(temperature, 67.5, %{"core" => "0"})
```

## Asynchronous (observable) instruments

The SDK calls a callback at each collection cycle to pull current values.

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

The callback receives `callback_args` (the 4th argument) and returns a
list of `%Measurement{}` — one per attribute set.

## Attributes

Every `add/3` / `record/3` / `Measurement{}` accepts an attribute map.
Cardinality is bounded by the SDK's per-instrument cardinality limit
(default 2000); excess attribute sets fold into an
`otel.metric.overflow` bucket.

```elixir
Otel.API.Metrics.Counter.add(counter, 1, %{
  "http.method" => "GET",
  "http.status_code" => 200,
  "http.route" => "/orders/:id"
})
```
