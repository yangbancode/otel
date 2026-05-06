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

  Three SDK-internal `XxxStorage` GenServers (one per ETS table)
  own the metrics state; they're started by
  `Otel.Application.start/2` and die with the SDK supervisor.
  Every other knob (scope, exemplar filter) is a compile-time
  literal — exemplar filter is hardcoded to `:trace_based` per
  the wire-format invariant in `Otel.Metrics.Exemplar.Filter`.

  ## Public API

  | Function | Role |
  |---|---|
  | `meter_config/0` | **SDK** — config stamped on `Meter.create_*` and consumed by `Otel.Metrics.MetricExporter.collect/1`; also serves as Application-side introspection of the resource/scope |

  ## References

  - OTel Metrics SDK §MeterProvider: `opentelemetry-specification/specification/metrics/sdk.md` L43-L155
  """

  @doc """
  **SDK** — Returns the meter config used by both `Meter.create_*`
  (producer side) and `Otel.Metrics.MetricExporter.collect/1`
  (consumer side). The same map serves both roles so callers
  don't juggle two shapes.

  Application code may also call this for introspection (e.g.
  reading `.resource` or `.scope`) — there is no separate
  introspection API.
  """
  @spec meter_config() :: map()
  def meter_config do
    %{
      scope: Otel.InstrumentationScope.new(),
      resource: Otel.Resource.new(),
      instruments_tab: Otel.Metrics.InstrumentsStorage,
      metrics_tab: Otel.Metrics.MetricsStorage,
      exemplars_tab: Otel.Metrics.ExemplarsStorage
    }
  end
end
