defmodule Otel.Metrics.MeterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defp restart_sdk(env), do: Otel.TestSupport.restart_with(env)
  defp config, do: Otel.Metrics.meter_config()

  defp datapoints(name, agg_module) do
    cfg = config()
    agg_module.collect(cfg.metrics_tab, {name, cfg.scope}, %{reader_id: cfg.reader_id})
  end

  setup do
    restart_sdk(metrics: [readers: []])
    :ok
  end

  describe "instrument creation" do
    test "create_* returns a typed Instrument struct for every kind" do
      assert %{name: "c", kind: :counter} =
               Otel.Metrics.Meter.create_counter("c", [])

      assert %{name: "h", kind: :histogram} =
               Otel.Metrics.Meter.create_histogram("h", [])

      assert %{name: "g", kind: :gauge} =
               Otel.Metrics.Meter.create_gauge("g", [])

      assert %{name: "udc", kind: :updown_counter} =
               Otel.Metrics.Meter.create_updown_counter("udc", [])
    end
  end

  describe "instrument opts" do
    test "unit + description + advisory pass through verbatim; nil → \"\" / []" do
      result =
        Otel.Metrics.Meter.create_counter("req",
          unit: "1",
          description: "Requests",
          advisory: [attributes: ["method", "status"]]
        )

      assert result.unit == "1"
      assert result.description == "Requests"
      assert result.advisory == [attributes: ["method", "status"]]

      nil_opts = Otel.Metrics.Meter.create_counter("nilopts", unit: nil, description: nil)
      assert nil_opts.unit == ""
      assert nil_opts.description == ""

      hist =
        Otel.Metrics.Meter.create_histogram("dur",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      assert hist.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    # Spec metrics/api.md L196-L211 MUST: unit ≥63 chars,
    # description ≥1023 chars, both case-sensitive, BMP support.
    test "unit ≥63 chars / description ≥1023 chars / case-sensitive / BMP characters" do
      lower = Otel.Metrics.Meter.create_counter("bytes_lower", unit: "kb")
      upper = Otel.Metrics.Meter.create_counter("bytes_upper", unit: "kB")
      assert lower.unit == "kb"
      assert upper.unit == "kB"

      long_unit = String.duplicate("a", 63)
      long_desc = String.duplicate("d", 1023)

      result =
        Otel.Metrics.Meter.create_counter("long",
          unit: long_unit,
          description: long_desc
        )

      assert result.unit == long_unit
      assert result.description == long_desc

      bmp = "Request count — 요청 ★ €"
      bmp_result = Otel.Metrics.Meter.create_counter("bmp", description: bmp)
      assert bmp_result.description == bmp
    end
  end

  describe "duplicate detection" do
    test "identical → same struct; case-insensitive → first-seen name wins" do
      first = Otel.Metrics.Meter.create_counter("RequestCount", unit: "1")
      assert first == Otel.Metrics.Meter.create_counter("RequestCount", unit: "1")

      case_dup = Otel.Metrics.Meter.create_counter("requestcount", unit: "1")
      assert case_dup.name == "RequestCount"
    end
  end

  describe "duplicate conflict resolution" do
    test "conflicting unit/description/kind/advisory all return first-seen instrument" do
      pairs = [
        {{"desc_dup", [unit: "1", description: "alpha"]}, &Otel.Metrics.Meter.create_counter/2,
         [unit: "1", description: "beta"]},
        {{"unit_dup", [unit: "1", description: "a"]}, &Otel.Metrics.Meter.create_counter/2,
         [unit: "ms", description: "a"]},
        {{"kind_dup", [unit: "1"]}, &Otel.Metrics.Meter.create_histogram/2, [unit: "1"]},
        {{"both_dup", [unit: "1"]}, &Otel.Metrics.Meter.create_histogram/2, [unit: "ms"]}
      ]

      for {{name, first_opts}, second_fn, second_opts} <- pairs do
        first = Otel.Metrics.Meter.create_counter(name, first_opts)
        second = second_fn.(name, second_opts)
        assert second == first
      end

      hist1 =
        Otel.Metrics.Meter.create_histogram("adv_dup",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      hist2 =
        Otel.Metrics.Meter.create_histogram("adv_dup",
          advisory: [explicit_bucket_boundaries: [100, 200]]
        )

      assert hist2 == hist1
      assert hist2.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    # Spec metrics/sdk.md L917-L930 — duplicate registration emits a
    # warning naming the conflicting field; identical re-registration
    # is silent.
    test "logs warning on conflicting duplicate; silent on identical re-registration" do
      log_conflict =
        capture_log(fn ->
          Otel.Metrics.Meter.create_counter("warn_dup", unit: "1")
          Otel.Metrics.Meter.create_counter("warn_dup", unit: "ms")
        end)

      assert log_conflict =~ "duplicate instrument registration"
      assert log_conflict =~ "warn_dup"
      assert log_conflict =~ ":unit"

      log_identical =
        capture_log(fn ->
          Otel.Metrics.Meter.create_counter("noop_dup", unit: "1", description: "x")
          Otel.Metrics.Meter.create_counter("noop_dup", unit: "1", description: "x")
        end)

      refute log_identical =~ "duplicate instrument registration"
    end
  end

  describe "record/3" do
    test "uses default aggregation per kind; aggregates across attribute sets" do
      counter = Otel.Metrics.Meter.create_counter("req", [])
      Otel.Metrics.Meter.record(counter, 5, %{"method" => "GET"})
      Otel.Metrics.Meter.record(counter, 3, %{"method" => "GET"})
      Otel.Metrics.Meter.record(counter, 1, %{"method" => "POST"})

      sum_dps = datapoints("req", Otel.Metrics.Aggregation.Sum)
      by_attr = Map.new(sum_dps, &{&1.attributes, &1.value})
      assert by_attr[%{"method" => "GET"}] == 8
      assert by_attr[%{"method" => "POST"}] == 1

      gauge = Otel.Metrics.Meter.create_gauge("temp", [])
      Otel.Metrics.Meter.record(gauge, 20, %{})
      Otel.Metrics.Meter.record(gauge, 25, %{})
      [dp] = datapoints("temp", Otel.Metrics.Aggregation.LastValue)
      assert dp.value == 25

      hist = Otel.Metrics.Meter.create_histogram("latency", [])
      Otel.Metrics.Meter.record(hist, 50, %{})
      Otel.Metrics.Meter.record(hist, 150, %{})

      [dp] = datapoints("latency", Otel.Metrics.Aggregation.ExplicitBucketHistogram)
      assert dp.value.count == 2
      assert dp.value.sum == 200
      assert dp.value.min == 50
      assert dp.value.max == 150
    end

    test "record on an unregistered instrument is a no-op (returns :ok)" do
      cfg = config()

      ghost = %Otel.Metrics.Instrument{
        config: cfg,
        name: "ghost",
        kind: :counter,
        scope: cfg.scope
      }

      assert :ok == Otel.Metrics.Meter.record(ghost, 1, %{})
    end
  end

  describe "cardinality limits" do
    test "default aggregation_cardinality_limit is 2000" do
      cfg = config()
      Otel.Metrics.Meter.create_counter("card_test", [])

      [{_, stream}] = :ets.lookup(cfg.streams_tab, {cfg.scope, "card_test"})
      assert stream.aggregation_cardinality_limit == 2000
    end
  end
end
