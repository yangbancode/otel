# MetricReader & Periodic Exporting

## Question

How to implement MetricReader interface and PeriodicExportingMetricReader on BEAM? Collection pipeline, temporality handling, scheduling?

## Decision

### MetricReader Behaviour

`Otel.SDK.Metrics.MetricReader` defines callbacks:
- `start_link(config)` — start the reader process
- `shutdown(server)` — final collect + export, stop
- `force_flush(server)` — immediate collect + export

`MetricReader.collect/1` is the collection pipeline entry point
(not a callback — called by reader implementations):
1. Runs async callbacks via `Meter.run_callbacks/1`
2. Iterates unique streams from `streams_tab`
3. Calls each stream's aggregation `collect` to get datapoints
4. Returns list of metric maps with name, description, unit,
   scope, resource, kind, and datapoints

### PeriodicExportingMetricReader

GenServer that periodically collects and exports metrics.

- `export_interval_ms` (default 60000)
- `exporter` — `{module, config}` tuple or nil
- Periodic timer via `Process.send_after`
- Export calls serialized through GenServer mailbox
- Shutdown: cancel timer → final collect + export → exporter shutdown
- ForceFlush: collect + export → exporter force_flush

### MeterProvider Integration

MeterProvider starts readers in `init/1`:
1. Creates `reader_meter_config` with shared ETS table refs
2. For each `{module, config}` in `readers`, calls
   `module.start_link(Map.put(config, :meter_config, ...))`
3. Stores `{module, pid}` for shutdown/force_flush dispatch

Reader invocation changed from `apply(module, function, [config])`
to `apply(module, function, [pid])` for GenServer-based readers.

### Deferred

- Temporality conversion (Cumulative/Delta checkpoint) — requires
  generation tracking and per-reader aggregation state
- Per-reader callback invocation isolation (L762)
- Multiple MetricReader side-effect isolation (L1367)
- MetricProducer integration (L1416)

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Metrics.MetricReader` | `metric_reader.ex` | Behaviour + collection pipeline |
| `Otel.SDK.Metrics.PeriodicExportingMetricReader` | `periodic_exporting_metric_reader.ex` | Periodic collection GenServer |

## Compliance

- [Metrics SDK](../compliance.md)
  * MetricReader (Stable) — L1302, L1305, L1306, L1307, L1318, L1321, L1339, L1342, L1345, L1354, L1357, L1359, L1365, L1367, L1374, L1391
  * Collect — L1406, L1416
  * Shutdown — L1430, L1431, L1434, L1437
  * Periodic Exporting MetricReader — L1455
  * ForceFlush (Periodic) — L1478, L1482, L1483, L1488
