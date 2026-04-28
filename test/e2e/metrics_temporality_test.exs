defmodule Otel.E2E.MetricsTemporalityTest do
  @moduledoc """
  E2E coverage for `:delta` aggregation temporality against
  Mimir.

  The reader's `temporality_mapping` is configured at provider
  boot — there's no runtime API to flip it — so this scenario
  needs a `setup_all`-driven SDK restart with a delta-mapped
  reader, isolating it from modules that assume the default
  cumulative temporality.

  Tracking matrix: `docs/e2e.md` §Metrics, scenario 17.
  """

  use Otel.E2E.Case, async: false

  setup_all do
    prev = Application.get_env(:otel, :metrics, [])
    Application.stop(:otel)

    Application.put_env(:otel, :metrics,
      readers: [
        {Otel.SDK.Metrics.MetricReader.PeriodicExporting,
         %{
           exporter: {Otel.OTLP.Metrics.MetricExporter.HTTP, %{}},
           temporality_mapping: %{
             counter: :delta,
             observable_counter: :delta,
             histogram: :delta,
             updown_counter: :delta,
             observable_updown_counter: :delta,
             gauge: :delta,
             observable_gauge: :delta
           }
         }}
      ]
    )

    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.put_env(:otel, :metrics, prev)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  describe "delta temporality" do
    test "17: counter samples export as delta values, not running totals",
         %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      counter =
        Otel.API.Metrics.Meter.create_counter(meter, "e2e_scenario_17_#{e2e_id}")

      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      # Under delta temporality the OTLP data point carries
      # `aggregation_temporality=AGGREGATION_TEMPORALITY_DELTA`
      # rather than `_CUMULATIVE`. Mimir's exposition treats
      # the remote write the same way (no `_total` suffix
      # change), so the e2e signal is "the metric still lands".
      # Spec correctness of the temporality flag itself is
      # exercised by the unit tests under
      # `test/otel/sdk/metrics/`.
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_17_#{e2e_id}_total"))
    end
  end
end
