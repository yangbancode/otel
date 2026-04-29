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
    test "17: delta-mapped reader exports without raising; Mimir drops the series",
         %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      metric = "e2e_scenario_17_#{e2e_id}"

      counter = Otel.API.Metrics.Meter.create_counter(meter, metric)

      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

      # `flush/0` synchronously forces the PeriodicExporting
      # reader to collect and ship the OTLP request. The
      # absence of a raise here is the SDK-side e2e signal:
      # delta encoding + transport completes end-to-end.
      flush()

      # LGTM 0.26.0's Mimir OTLP receiver drops delta-temporality
      # counters by default — its delta-to-cumulative conversion
      # is an experimental opt-in (off in this image). Asserting
      # that neither the `_total` (Prometheus naming) nor the
      # bare metric name lands documents that Mimir, not the
      # SDK, is the limiting factor here. Spec correctness of
      # the OTLP `aggregation_temporality` flag itself is
      # exercised by the encoder/temporality unit tests under
      # `test/otel/`.
      assert {:ok, []} = fetch(Mimir.query(e2e_id, "#{metric}_total"))
      assert {:ok, []} = fetch(Mimir.query(e2e_id, metric))
    end
  end
end
