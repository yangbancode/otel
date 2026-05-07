defmodule Otel.E2E.MetricsSyncTest do
  @moduledoc """
  E2E coverage for synchronous Metrics instruments against Mimir.

  Each scenario records measurements through one of the four
  sync instrument facades (`Counter`, `UpDownCounter`,
  `Histogram`, `Gauge`), force-flushes, and asserts on the
  resulting PromQL series **value** — not just its presence.
  Land-only checks (`{:ok, [_ | _]}`) silently passed when the
  aggregation logic was broken, so each scenario now reads
  `result["value"][1]` via `Mimir.value/1` and compares against
  the arithmetic expectation.

  Tracking matrix: `docs/e2e.md` §Metrics — sync instrument
  scenarios that work under the SDK's default configuration:
  rows 1–4, 8, 16, 21, 30, 31.

  Each test mints a metric name unique to the scenario + e2e_id
  and tags every measurement with `e2e.id` so Mimir's PromQL
  selector `metric{e2e_id="..."}` filters out the others.
  """

  use Otel.E2E.Case, async: false

  describe "sync instruments" do
    test "1: Counter records a single sample", %{e2e_id: e2e_id} do
      counter = Otel.Metrics.Meter.create_counter("e2e_scenario_1_#{e2e_id}")
      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_1_#{e2e_id}_total"))
      assert Mimir.value(result) == 1.0
    end

    test "2: Counter accumulates across N adds", %{e2e_id: e2e_id} do
      counter = Otel.Metrics.Meter.create_counter("e2e_scenario_2_#{e2e_id}")
      for _ <- 1..5, do: Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_2_#{e2e_id}_total"))
      # 5 events × `Counter.add(1)` = 5.
      assert Mimir.value(result) == 5.0
    end

    test "3: UpDownCounter accepts positive and negative deltas", %{e2e_id: e2e_id} do
      udc = Otel.Metrics.Meter.create_updown_counter("e2e_scenario_3_#{e2e_id}")

      Otel.Metrics.UpDownCounter.add(udc, 5, %{"e2e.id" => e2e_id})
      Otel.Metrics.UpDownCounter.add(udc, -2, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_3_#{e2e_id}"))
      # 5 + -2 = 3 — the negative delta was accepted.
      assert Mimir.value(result) == 3.0
    end

    test "4: Histogram records bucketed samples — count and sum match",
         %{e2e_id: e2e_id} do
      hist = Otel.Metrics.Meter.create_histogram("e2e_scenario_4_#{e2e_id}")
      values = [1.0, 5.0, 10.0, 50.0]

      for v <- values, do: Otel.Metrics.Histogram.record(hist, v, %{"e2e.id" => e2e_id})

      flush()

      assert {:ok, [count_r | _]} =
               poll(Mimir.query(e2e_id, "e2e_scenario_4_#{e2e_id}_count"))

      assert Mimir.value(count_r) == 4.0

      assert {:ok, [sum_r | _]} =
               poll(Mimir.query(e2e_id, "e2e_scenario_4_#{e2e_id}_sum"))

      assert Mimir.value(sum_r) == Enum.sum(values)
    end

    test "8: synchronous Gauge records the latest value", %{e2e_id: e2e_id} do
      gauge = Otel.Metrics.Meter.create_gauge("e2e_scenario_8_#{e2e_id}")
      Otel.Metrics.Gauge.record(gauge, 41, %{"e2e.id" => e2e_id})
      Otel.Metrics.Gauge.record(gauge, 42, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_8_#{e2e_id}"))
      # Last writer wins.
      assert Mimir.value(result) == 42.0
    end

    test "5: Histogram custom buckets via advisory carry through to Mimir",
         %{e2e_id: e2e_id} do
      bounds = [1.0, 5.0, 25.0]

      hist =
        Otel.Metrics.Meter.create_histogram("e2e_scenario_5_#{e2e_id}",
          advisory: [explicit_bucket_boundaries: bounds]
        )

      # 0.5 → le="1", 3.0 → le="5", 10.0 → le="25". Cumulative
      # bucket counts: 1, 2, 3 (and 3 for +Inf).
      for v <- [0.5, 3.0, 10.0],
          do: Otel.Metrics.Histogram.record(hist, v, %{"e2e.id" => e2e_id})

      flush()

      base = "e2e_scenario_5_#{e2e_id}_bucket"

      assert {:ok, [r1 | _]} = poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",le="1"}|))

      assert {:ok, [r5 | _]} = poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",le="5"}|))

      assert {:ok, [r25 | _]} = poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",le="25"}|))

      assert Mimir.value(r1) == 1.0
      assert Mimir.value(r5) == 2.0
      assert Mimir.value(r25) == 3.0
    end

    test "18: multi-dimensional attrs produce one Mimir series per attr combination",
         %{e2e_id: e2e_id} do
      counter = Otel.Metrics.Meter.create_counter("e2e_scenario_18_#{e2e_id}")

      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id, "host" => "a"})
      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id, "host" => "a"})
      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id, "host" => "b"})
      flush()

      assert {:ok, results} = poll(Mimir.query(e2e_id, "e2e_scenario_18_#{e2e_id}_total"))
      # Two distinct `host` values → two distinct PromQL series,
      # each with its own arithmetic count.
      assert length(results) == 2

      by_host = Map.new(results, fn r -> {Mimir.label(r, "host"), Mimir.value(r)} end)
      assert by_host == %{"a" => 2.0, "b" => 1.0}
    end
  end

  describe "semantics" do
    test "16: cumulative temporality is the default — counter monotonically increases",
         %{e2e_id: e2e_id} do
      counter = Otel.Metrics.Meter.create_counter("e2e_scenario_16_#{e2e_id}")

      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_16_#{e2e_id}_total"))
      # Cumulative — 2 adds total to 2 (delta would reset between
      # collects and Mimir would see 1 + 1 separately).
      assert Mimir.value(result) == 2.0
    end

    test "21: float and int values mix on the same series", %{e2e_id: e2e_id} do
      hist = Otel.Metrics.Meter.create_histogram("e2e_scenario_21_#{e2e_id}")
      Otel.Metrics.Histogram.record(hist, 1, %{"e2e.id" => e2e_id})
      Otel.Metrics.Histogram.record(hist, 1.5, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [count_r | _]} =
               poll(Mimir.query(e2e_id, "e2e_scenario_21_#{e2e_id}_count"))

      assert Mimir.value(count_r) == 2.0

      assert {:ok, [sum_r | _]} =
               poll(Mimir.query(e2e_id, "e2e_scenario_21_#{e2e_id}_sum"))

      # 1 + 1.5 = 2.5 confirms int and float coexist on the same
      # cell without precision loss.
      assert Mimir.value(sum_r) == 2.5
    end
  end

  describe "operations" do
    test "30: MetricExporter force_flush surfaces data immediately", %{e2e_id: e2e_id} do
      counter = Otel.Metrics.Meter.create_counter("e2e_scenario_30_#{e2e_id}")

      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      # `flush/0` calls every provider's force_flush — so the
      # poll succeeding before the next periodic tick proves
      # force_flush did its job. The numeric value confirms the
      # data wasn't lost.
      flush()

      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "e2e_scenario_30_#{e2e_id}_total"))

      assert Mimir.value(result) == 1.0
    end

    test "31: case-insensitive duplicate registration returns the first instrument",
         %{e2e_id: e2e_id} do
      # First registration sets the canonical (lowercase) name —
      # Mimir stores series under that exact name. The second
      # call uses uppercase to exercise the case-insensitive
      # duplicate-name contract; the SDK warns and returns the
      # first instrument, so both `add/3` calls feed the same
      # series.
      first = Otel.Metrics.Meter.create_counter("e2e_scenario_31_#{e2e_id}")
      second = Otel.Metrics.Meter.create_counter("E2E_SCENARIO_31_#{e2e_id}")
      Otel.Metrics.Counter.add(first, 1, %{"e2e.id" => e2e_id})
      Otel.Metrics.Counter.add(second, 1, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "e2e_scenario_31_#{e2e_id}_total"))

      # 2 adds against the same (deduplicated) instrument →
      # accumulated value of 2. If the SDK had created two
      # separate instruments, the lowercase query would see only
      # the first.
      assert Mimir.value(result) == 2.0
    end
  end
end
