defmodule Otel.E2E.TelemetryReporterTest do
  @moduledoc """
  E2E coverage for the `:telemetry` → OTel Metrics bridge
  (`Otel.TelemetryReporter`) against Mimir.

  Each scenario starts a reporter with one or more
  `Telemetry.Metrics` definitions whose names carry the
  per-test `e2e_id`, dispatches `:telemetry.execute` calls,
  then asserts the resulting PromQL series shows up in
  Mimir **and** carries the expected numeric value /
  label / bucket distribution.

  Tracking matrix: `docs/e2e.md` §Metrics — Telemetry reporter.

  ## What is *not* exercised here

  `:description` is not e2e-tested. Our OTLP encoder writes the
  `description` field on the wire (`encode_metric/1` in
  `lib/otel/otlp/encoder.ex`, covered by
  `test/otel/otlp/encoder_test.exs`), but the LGTM bundle's
  Mimir does not expose OTLP-pushed metadata via
  `/api/v1/metadata` — that endpoint is populated only from
  scrape-target configurations, which we don't use. The wire
  shape is verified at the encoder unit-test level instead.
  """

  use Otel.E2E.Case, async: false

  import Telemetry.Metrics

  describe "telemetry → OTel Metrics → Mimir" do
    test "1: Counter — :telemetry events count up", %{e2e_id: e2e_id} do
      metric_name = "telem.counter.#{e2e_id}.count"
      event = [:"telem_counter_#{e2e_id}"]

      start_reporter!([counter(metric_name, event_name: event, tags: [:e2e_id])])

      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id})
      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id})

      flush()

      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "telem_counter_#{e2e_id}_count_total"))

      # 2 events × `Counter.add(1)` = 2.
      assert Mimir.value(result) == 2.0
    end

    test "2: Sum (default UpDownCounter) — accepts negative deltas", %{e2e_id: e2e_id} do
      metric_name = "telem.sum.#{e2e_id}.delta"
      event = [:"telem_sum_#{e2e_id}"]

      start_reporter!([
        sum(metric_name, event_name: event, measurement: :delta, tags: [:e2e_id])
      ])

      :telemetry.execute(event, %{delta: 5}, %{e2e_id: e2e_id})
      :telemetry.execute(event, %{delta: -2}, %{e2e_id: e2e_id})

      flush()
      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "telem_sum_#{e2e_id}_delta"))
      # 5 + -2 = 3 — confirms UpDownCounter accepted the negative.
      assert Mimir.value(result) == 3.0
    end

    test "3: LastValue → Gauge — keeps the latest measurement", %{e2e_id: e2e_id} do
      metric_name = "telem.last.#{e2e_id}.value"
      event = [:"telem_last_#{e2e_id}"]

      start_reporter!([
        last_value(metric_name, event_name: event, measurement: :value, tags: [:e2e_id])
      ])

      :telemetry.execute(event, %{value: 100}, %{e2e_id: e2e_id})
      :telemetry.execute(event, %{value: 250}, %{e2e_id: e2e_id})

      flush()
      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "telem_last_#{e2e_id}_value"))
      # 100 then 250 — last writer wins.
      assert Mimir.value(result) == 250.0
    end

    test "4: Summary → Histogram — count and sum match the recorded values",
         %{e2e_id: e2e_id} do
      metric_name = "telem.summary.#{e2e_id}.duration"
      event = [:"telem_summary_#{e2e_id}"]

      start_reporter!([
        summary(metric_name, event_name: event, measurement: :duration, tags: [:e2e_id])
      ])

      for v <- [10, 50, 200],
          do: :telemetry.execute(event, %{duration: v}, %{e2e_id: e2e_id})

      flush()

      assert {:ok, [count_result | _]} =
               poll(Mimir.query(e2e_id, "telem_summary_#{e2e_id}_duration_count"))

      assert Mimir.value(count_result) == 3.0

      assert {:ok, [sum_result | _]} =
               poll(Mimir.query(e2e_id, "telem_summary_#{e2e_id}_duration_sum"))

      assert Mimir.value(sum_result) == 260.0
    end

    test "5: Distribution with custom buckets → bucket counts match the bounds",
         %{e2e_id: e2e_id} do
      metric_name = "telem.dist.#{e2e_id}.duration"
      event = [:"telem_dist_#{e2e_id}"]

      start_reporter!([
        distribution(metric_name,
          event_name: event,
          measurement: :duration,
          tags: [:e2e_id],
          reporter_options: [buckets: [10, 100, 1000]]
        )
      ])

      # 5 → bucket le="10", 50 → le="100", 500 → le="1000",
      # 5000 → le="+Inf". Cumulative bucket counts:
      # le="10"   = 1 (just 5)
      # le="100"  = 2 (5, 50)
      # le="1000" = 3 (5, 50, 500)
      # le="+Inf" = 4 (all)
      for v <- [5, 50, 500, 5000],
          do: :telemetry.execute(event, %{duration: v}, %{e2e_id: e2e_id})

      flush()

      base = "telem_dist_#{e2e_id}_duration_bucket"

      assert {:ok, [r10 | _]} =
               poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",le="10"}|))

      assert {:ok, [r100 | _]} =
               poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",le="100"}|))

      assert {:ok, [r1000 | _]} =
               poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",le="1000"}|))

      assert Mimir.value(r10) == 1.0
      assert Mimir.value(r100) == 2.0
      assert Mimir.value(r1000) == 3.0
    end

    test "9: Sum with reporter_options[:monotonic]: true → Counter (`_total` suffix)",
         %{e2e_id: e2e_id} do
      metric_name = "telem.mono.#{e2e_id}.bytes"
      event = [:"telem_mono_#{e2e_id}"]

      start_reporter!([
        sum(metric_name,
          event_name: event,
          measurement: :bytes,
          tags: [:e2e_id],
          reporter_options: [monotonic: true]
        )
      ])

      for v <- [100, 250, 600],
          do: :telemetry.execute(event, %{bytes: v}, %{e2e_id: e2e_id})

      flush()

      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "telem_mono_#{e2e_id}_bytes_total"))

      # 100 + 250 + 600 = 950, AND the `_total` suffix proves
      # Counter wire shape (UpDownCounter wouldn't get the suffix).
      assert Mimir.value(result) == 950.0
    end
  end

  describe "tags / unit / keep / drop / measurement" do
    test "6: tags split events into separate Mimir series, each with its own value",
         %{e2e_id: e2e_id} do
      metric_name = "telem.multi.#{e2e_id}.count"
      event = [:"telem_multi_#{e2e_id}"]

      start_reporter!([counter(metric_name, event_name: event, tags: [:e2e_id, :role])])

      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, role: "admin"})
      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, role: "admin"})
      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, role: "user"})

      flush()

      assert {:ok, results} =
               poll(Mimir.query(e2e_id, "telem_multi_#{e2e_id}_count_total"))

      assert length(results) == 2

      by_role = Map.new(results, fn r -> {Mimir.label(r, "role"), Mimir.value(r)} end)
      assert by_role == %{"admin" => 2.0, "user" => 1.0}
    end

    test "7: unit {:native, :millisecond} arrives in Mimir as the converted ms value",
         %{e2e_id: e2e_id} do
      metric_name = "telem.unit.#{e2e_id}.duration"
      event = [:"telem_unit_#{e2e_id}"]

      start_reporter!([
        last_value(metric_name,
          event_name: event,
          measurement: :duration,
          unit: {:native, :millisecond},
          tags: [:e2e_id]
        )
      ])

      native = System.convert_time_unit(750, :millisecond, :native)
      :telemetry.execute(event, %{duration: native}, %{e2e_id: e2e_id})

      flush()
      # OTLP→Prom translator appends the unit name as a metric
      # suffix (`_millisecond`); the value asserts conversion
      # actually happened (raw native would be ~750_000_000).
      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "telem_unit_#{e2e_id}_duration_millisecond"))

      assert Mimir.value(result) == 750.0
    end

    test "8: :keep predicate filters events; dropped events do NOT land in Mimir",
         %{e2e_id: e2e_id} do
      metric_name = "telem.keep.#{e2e_id}.count"
      event = [:"telem_keep_#{e2e_id}"]

      keep_prod = fn meta -> meta[:env] == :prod end

      start_reporter!([
        counter(metric_name,
          event_name: event,
          keep: keep_prod,
          tags: [:e2e_id, :env]
        )
      ])

      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, env: :test})
      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, env: :prod})
      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, env: :prod})

      flush()

      base = "telem_keep_#{e2e_id}_count_total"

      # Positive: prod events landed (count == 2).
      assert {:ok, [prod_r | _]} =
               poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",env="prod"}|))

      assert Mimir.value(prod_r) == 2.0

      # Negative: filtered (env=test) events DIDN'T land. If the
      # filter were broken, Mimir would already hold the test
      # series here (prod presence above proves ingest finished).
      assert {:ok, []} = fetch(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",env="test"}|))
    end
  end

  describe "drop / tag_values / function-measurement / byte / atom-unit / description" do
    test "10: :drop predicate filters events; dropped events do NOT land",
         %{e2e_id: e2e_id} do
      metric_name = "telem.drop.#{e2e_id}.count"
      event = [:"telem_drop_#{e2e_id}"]

      drop_test = fn meta -> meta[:env] == :test end

      start_reporter!([
        counter(metric_name,
          event_name: event,
          drop: drop_test,
          tags: [:e2e_id, :env]
        )
      ])

      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, env: :test})
      :telemetry.execute(event, %{count: 1}, %{e2e_id: e2e_id, env: :prod})

      flush()

      base = "telem_drop_#{e2e_id}_count_total"

      # Positive: prod event landed.
      assert {:ok, [prod_r | _]} =
               poll(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",env="prod"}|))

      assert Mimir.value(prod_r) == 1.0

      # Negative: dropped (env=test) event didn't land.
      assert {:ok, []} = fetch(Mimir.query(~s|#{base}{e2e_id="#{e2e_id}",env="test"}|))
    end

    test "11: :tag_values transforms metadata before tagging — emitted labels match",
         %{e2e_id: e2e_id} do
      metric_name = "telem.tagxform.#{e2e_id}.count"
      event = [:"telem_tagxform_#{e2e_id}"]

      tag_fn = fn meta -> %{e2e_id: meta.e2e_id, role: to_string(meta.user.role)} end

      start_reporter!([
        counter(metric_name,
          event_name: event,
          tags: [:e2e_id, :role],
          tag_values: tag_fn
        )
      ])

      :telemetry.execute(event, %{count: 1}, %{
        e2e_id: e2e_id,
        user: %{role: :admin, name: "alice"}
      })

      flush()

      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "telem_tagxform_#{e2e_id}_count_total"))

      # The tag_values fn flattened `meta.user.role` (an atom) into
      # a top-level `role="admin"` label. If tag_values were
      # ignored, the role label would be absent.
      assert Mimir.label(result, "role") == "admin"
      assert Mimir.value(result) == 1.0
    end

    test "12: function `:measurement` (1-arity) computes from measurements map",
         %{e2e_id: e2e_id} do
      metric_name = "telem.fnmeas.#{e2e_id}.total"
      event = [:"telem_fnmeas_#{e2e_id}"]
      mfn = fn meas -> meas[:in] + meas[:out] end

      start_reporter!([
        last_value(metric_name,
          event_name: event,
          measurement: mfn,
          tags: [:e2e_id]
        )
      ])

      :telemetry.execute(event, %{in: 100, out: 250}, %{e2e_id: e2e_id})

      flush()

      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "telem_fnmeas_#{e2e_id}_total"))

      # 100 + 250 — confirms the fn ran and its output reached the
      # OTel instrument. If the fn were ignored, the `in` or `out`
      # key alone would be in `value`, never their sum.
      assert Mimir.value(result) == 350.0
    end

    test "13: byte unit conversion `{:byte, :kilobyte}` lands as decimal kB value",
         %{e2e_id: e2e_id} do
      metric_name = "telem.bytes.#{e2e_id}.heap"
      event = [:"telem_bytes_#{e2e_id}"]

      start_reporter!([
        last_value(metric_name,
          event_name: event,
          measurement: :bytes,
          unit: {:byte, :kilobyte},
          tags: [:e2e_id]
        )
      ])

      :telemetry.execute(event, %{bytes: 4096}, %{e2e_id: e2e_id})

      flush()
      # `Telemetry.Metrics` byte conversion is **decimal**:
      # 4096 / 1000 = 4.096. (Binary 1024 would give 4.0.)
      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "telem_bytes_#{e2e_id}_heap_kilobyte"))

      assert Mimir.value(result) == 4.096
    end

    test "14: atom-only unit (no conversion) lands with that unit as suffix",
         %{e2e_id: e2e_id} do
      metric_name = "telem.unit2.#{e2e_id}.size"
      event = [:"telem_unit2_#{e2e_id}"]

      start_reporter!([
        last_value(metric_name,
          event_name: event,
          measurement: :size,
          unit: :byte,
          tags: [:e2e_id]
        )
      ])

      :telemetry.execute(event, %{size: 12_345}, %{e2e_id: e2e_id})

      flush()

      assert {:ok, [result | _]} =
               poll(Mimir.query(e2e_id, "telem_unit2_#{e2e_id}_size_byte"))

      # No conversion — the value passes through as-is.
      assert Mimir.value(result) == 12_345.0
    end
  end

  # --- helpers ---

  defp start_reporter!(metrics) do
    pid = start_supervised!({Otel.TelemetryReporter, metrics: metrics})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    pid
  end
end
