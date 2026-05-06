defmodule Otel.Metrics do
  @moduledoc """
  Metrics API facade.

  Minikube has no plugin ecosystem, so the spec's
  MeterProvider + Meter entities collapse to a single hardcoded
  identity. There is no `Meter` handle to obtain via
  `get_meter/0` first — call the instrument facades
  (`Otel.Metrics.Counter`, `Otel.Metrics.Histogram`, etc.)
  directly with just the instrument name + opts.

  Three SDK-internal `XxxStorage` GenServers (one per ETS table)
  own the metrics state; they're started by
  `Otel.Application.start/2` and die with the SDK supervisor.
  All knobs (scope, resource, exemplar filter, table identifiers)
  are compile-time literals — `Otel.InstrumentationScope.new/0`
  and `Otel.Resource.new/0` are pure functions called directly
  at the relevant boundaries, and the ETS tables are referenced
  by their module-name atoms (`Otel.Metrics.InstrumentsStorage`,
  `Otel.Metrics.MetricsStorage`, `Otel.Metrics.ExemplarsStorage`).

  ## References

  - OTel Metrics API §MeterProvider: `opentelemetry-specification/specification/metrics/api.md` L156-L499
  - OTel Metrics SDK §MeterProvider: `opentelemetry-specification/specification/metrics/sdk.md` L43-L155
  """
end
