defmodule Otel.Metrics do
  @moduledoc """
  Metrics API facade — instrument creation/record entry points
  (`metrics/api.md` §MeterProvider L156-L499 + §Meter
  §Instrument).

  Minikube has no plugin ecosystem, so the spec's
  MeterProvider + Meter entities collapse to a single hardcoded
  identity. There is no `Meter` handle to obtain via
  `get_meter/0` first — call the instrument facades
  (`Otel.Metrics.Counter`, `Otel.Metrics.Histogram`, etc.)
  directly with just the instrument name + opts.

  Six SDK-internal `XxxStorage` GenServers (one per ETS table)
  own the metrics state; they're started by
  `Otel.Application.start/2` and die with the SDK supervisor.
  Every other knob (scope, exemplar filter, reader id,
  temporality mapping) is a compile-time literal.

  ## Public API

  | Function | Role |
  |---|---|
  | `reader_meter_config/0` | **SDK** — config the reader uses to collect |
  | `resource/0`, `config/0` | **Application** (introspection) |
  | `meter_config/0` | **SDK** — the same map stamped on `Meter.create_*` paths |

  ## References

  - OTel Metrics SDK §MeterProvider: `opentelemetry-specification/specification/metrics/sdk.md` L43-L155
  """

  # Hardcoded identifiers shared by Meter and MetricReader.
  # `reader_id` was a `make_ref/0` reference back when the SDK
  # supported multiple readers; minikube has exactly one, so a
  # stable atom suffices.
  @reader_id :default_reader

  @doc """
  **SDK** — Returns the meter config used by both `Meter.create_*`
  (producer side, `reader_configs`) and `MetricReader.collect/1`
  (consumer side, `reader_id` + `temporality_mapping`). The same
  map serves both roles so callers don't juggle two shapes.
  """
  @spec meter_config() :: map()
  def meter_config do
    temporality_mapping = Otel.Metrics.Instrument.default_temporality_mapping()

    %{
      scope: %Otel.InstrumentationScope{},
      resource: Otel.Resource.build(),
      instruments_tab: Otel.Metrics.InstrumentsStorage,
      streams_tab: Otel.Metrics.StreamsStorage,
      metrics_tab: Otel.Metrics.MetricsStorage,
      callbacks_tab: Otel.Metrics.CallbacksStorage,
      exemplars_tab: Otel.Metrics.ExemplarsStorage,
      observed_attrs_tab: Otel.Metrics.ObservedAttrsStorage,
      exemplar_filter: :trace_based,
      reader_id: @reader_id,
      temporality_mapping: temporality_mapping,
      reader_configs: [{@reader_id, %{temporality_mapping: temporality_mapping}}]
    }
  end

  @doc """
  **SDK** — Same map as `meter_config/0`, kept for clarity at
  the `Otel.Metrics.MetricReader.PeriodicExporting` callsite.
  """
  @spec reader_meter_config() :: map()
  def reader_meter_config, do: meter_config()

  @doc """
  **Application** (introspection) — Returns the SDK resource
  (`Otel.Resource.build/0`).
  """
  @spec resource() :: Otel.Resource.t()
  def resource, do: Otel.Resource.build()

  @doc """
  **Application** (introspection) — Returns the synthetic meter
  config map (`meter_config/0`).
  """
  @spec config() :: map()
  def config, do: meter_config()
end
