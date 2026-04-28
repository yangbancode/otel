defmodule Otel.E2E.MetricsSyncTest do
  @moduledoc """
  E2E coverage for synchronous Metrics instruments against Mimir.

  Tracking matrix: `docs/e2e.md` §Metrics — sync instrument
  scenarios that work under the SDK's default configuration:
  rows 1–4, 8, 16, 21, 30, 31. Aggregation overrides
  (`record_min_max: false`, base2 exponential, drop, etc.) need
  per-test View / temporality config and live in
  `metrics_views_test.exs`.

  Each test mints a metric name unique to the scenario + e2e_id
  and tags every measurement with `e2e.id` so Mimir's PromQL
  selector `metric{e2e_id="..."}` filters out the others.
  """

  use Otel.E2E.Case, async: false

  describe "sync instruments" do
    test "1: Counter records a single sample", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      counter = Otel.API.Metrics.Meter.create_counter(meter, "e2e_scenario_1_#{e2e_id}")
      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_1_#{e2e_id}_total"))
    end

    test "2: Counter accumulates across N adds", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      counter = Otel.API.Metrics.Meter.create_counter(meter, "e2e_scenario_2_#{e2e_id}")
      for _ <- 1..5, do: Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_2_#{e2e_id}_total"))
    end

    test "3: UpDownCounter accepts positive and negative deltas", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      udc =
        Otel.API.Metrics.Meter.create_updown_counter(meter, "e2e_scenario_3_#{e2e_id}")

      Otel.API.Metrics.UpDownCounter.add(udc, 5, %{"e2e.id" => e2e_id})
      Otel.API.Metrics.UpDownCounter.add(udc, -2, %{"e2e.id" => e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_3_#{e2e_id}"))
    end

    test "4: Histogram records bucketed samples", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      hist = Otel.API.Metrics.Meter.create_histogram(meter, "e2e_scenario_4_#{e2e_id}")

      for v <- [1.0, 5.0, 10.0, 50.0],
          do: Otel.API.Metrics.Histogram.record(hist, v, %{"e2e.id" => e2e_id})

      flush()
      # Histograms are exposed via the `_count`, `_sum`, `_bucket` series.
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_4_#{e2e_id}_count"))
    end

    test "8: synchronous Gauge records the latest value", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      gauge = Otel.API.Metrics.Meter.create_gauge(meter, "e2e_scenario_8_#{e2e_id}")
      Otel.API.Metrics.Gauge.record(gauge, 42, %{"e2e.id" => e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_8_#{e2e_id}"))
    end
  end

  describe "semantics" do
    test "16: cumulative temporality is the default — counter monotonically increases",
         %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      counter =
        Otel.API.Metrics.Meter.create_counter(meter, "e2e_scenario_16_#{e2e_id}")

      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_16_#{e2e_id}_total"))
    end

    test "21: float and int values mix on the same series", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      hist = Otel.API.Metrics.Meter.create_histogram(meter, "e2e_scenario_21_#{e2e_id}")
      Otel.API.Metrics.Histogram.record(hist, 1, %{"e2e.id" => e2e_id})
      Otel.API.Metrics.Histogram.record(hist, 1.5, %{"e2e.id" => e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_21_#{e2e_id}_count"))
    end
  end

  describe "operations" do
    test "30: PeriodicExporting force_flush surfaces data immediately", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      counter =
        Otel.API.Metrics.Meter.create_counter(meter, "e2e_scenario_30_#{e2e_id}")

      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      # `flush/0` calls every provider's force_flush — so the
      # poll succeeding before the next periodic tick proves
      # force_flush did its job.
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_30_#{e2e_id}_total"))
    end

    test "31: case-insensitive duplicate registration returns the first instrument",
         %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      first = Otel.API.Metrics.Meter.create_counter(meter, "E2E_Scenario_31_#{e2e_id}")
      second = Otel.API.Metrics.Meter.create_counter(meter, "e2e_scenario_31_#{e2e_id}")
      # Duplicate (case-insensitive) registration warns and
      # returns the original instrument; both adds land on the
      # same series.
      Otel.API.Metrics.Counter.add(first, 1, %{"e2e.id" => e2e_id})
      Otel.API.Metrics.Counter.add(second, 1, %{"e2e.id" => e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_31_#{e2e_id}_total"))
    end
  end
end
