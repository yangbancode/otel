defmodule Otel.Metrics.Metric do
  @moduledoc """
  Metric data model — one metric record produced by
  `Otel.Metrics.MetricExporter.collect/1` and consumed by
  `Otel.OTLP.Encoder.encode_metrics/1` (`metrics/data-model.md`
  §Metric L300-L391; Status: **Stable**).

  Sibling to `Otel.Trace.Span` (Trace) and `Otel.Logs.LogRecord`
  (Logs) — the unit that crosses the SDK→encoder boundary for
  the Metrics pillar.

  Unlike Span / LogRecord — which are constructed at the
  *producer* side and flow through storage to the exporter —
  the Metric struct is **transient**: producers (`Counter.add`,
  `Histogram.record`, etc.) mutate per-attribute aggregation
  cells in `MetricsStorage`, and `MetricExporter.collect/1`
  builds Metric records on the fly by walking
  `InstrumentsStorage` and reading the latest aggregation
  snapshots from `MetricsStorage`. The struct exists only
  between `collect/1` and `encode_metrics/1`.

  Construct via `Otel.Metrics.Metric.new/1` — the canonical
  constructor that fills proto3-aligned defaults plus
  runtime-derived `scope` / `resource`.

  ## Field defaults — proto3-aligned

  | Field | Default | Basis |
  |---|---|---|
  | `name` | `""` | proto `string`; `metrics.proto` Metric.name |
  | `description` | `""` | proto `string`; `metrics.proto` Metric.description |
  | `unit` | `""` | proto `string`; `metrics.proto` Metric.unit |
  | `scope` | `Otel.InstrumentationScope.new()` | always overwritten by `collect/1` with the stream's instrument scope |
  | `resource` | `Otel.Resource.new()` | always overwritten by `collect/1` with `meter_config.resource` |
  | `kind` | `nil` | always populated; no spec-aligned default exists |
  | `temporality` | `nil` | nil for Gauge / LastValue per `data-model.md` §Temporality (gauges have no aggregation temporality) |
  | `is_monotonic` | `nil` | nil for non-Sum aggregations; `true` only for `Counter`, `false` for `UpDownCounter` |
  | `datapoints` | `[]` | proto `repeated`; empty when no measurements were recorded for the stream in the collect window |

  ## References

  - OTel Metrics Data Model §Metric: `opentelemetry-specification/specification/metrics/data-model.md` L300-L391
  - OTLP proto `Metric`: `opentelemetry-proto/opentelemetry/proto/metrics/v1/metrics.proto`
  """

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          unit: String.t(),
          scope: Otel.InstrumentationScope.t(),
          resource: Otel.Resource.t(),
          kind: Otel.Metrics.Instrument.kind() | nil,
          temporality: Otel.Metrics.Instrument.temporality() | nil,
          is_monotonic: boolean() | nil,
          datapoints: [Otel.Metrics.Aggregation.datapoint()]
        }

  defstruct [
    :name,
    :description,
    :unit,
    :scope,
    :resource,
    :kind,
    :temporality,
    :is_monotonic,
    :datapoints
  ]

  @doc """
  **SDK** — Construct a Metric. Caller provides at least
  `name`, `kind`, and `datapoints` via `opts`; remaining
  fields default to proto3 zero values plus runtime-derived
  `scope` / `resource`.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    defaults = %{
      name: "",
      description: "",
      unit: "",
      scope: Otel.InstrumentationScope.new(),
      resource: Otel.Resource.new(),
      kind: nil,
      temporality: nil,
      is_monotonic: nil,
      datapoints: []
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end
end
