defmodule Otel.SDK.Metrics.MeterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)
  end

  defp meter_for(scope_name \\ "test_lib") do
    {_, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.InstrumentationScope{name: scope_name}
      )

    {Otel.SDK.Metrics.Meter, config}
  end

  defp config_of({_, config}), do: config

  defp datapoints(meter, name, agg_module) do
    cfg = config_of(meter)
    agg_module.collect(cfg.metrics_tab, {name, cfg.scope}, %{})
  end

  setup do
    restart_sdk(metrics: [readers: []])
    %{meter: meter_for()}
  end

  describe "instrument creation" do
    test "create_* returns a typed Instrument struct for every kind", %{meter: meter} do
      assert %{name: "c", kind: :counter} =
               Otel.SDK.Metrics.Meter.create_counter(meter, "c", [])

      assert %{name: "h", kind: :histogram} =
               Otel.SDK.Metrics.Meter.create_histogram(meter, "h", [])

      assert %{name: "g", kind: :gauge} =
               Otel.SDK.Metrics.Meter.create_gauge(meter, "g", [])

      assert %{name: "udc", kind: :updown_counter} =
               Otel.SDK.Metrics.Meter.create_updown_counter(meter, "udc", [])

      assert %{name: "oc", kind: :observable_counter} =
               Otel.SDK.Metrics.Meter.create_observable_counter(meter, "oc", [])

      assert %{name: "og", kind: :observable_gauge} =
               Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "og", [])

      assert %{name: "oudc", kind: :observable_updown_counter} =
               Otel.SDK.Metrics.Meter.create_observable_updown_counter(meter, "oudc", [])
    end

    test "observable kinds also accept the with-callback /5 form", %{meter: meter} do
      cb = fn _args -> [%Otel.API.Metrics.Measurement{value: 1}] end

      for {fun, kind} <- [
            {:create_observable_counter, :observable_counter},
            {:create_observable_gauge, :observable_gauge},
            {:create_observable_updown_counter, :observable_updown_counter}
          ] do
        result = apply(Otel.SDK.Metrics.Meter, fun, [meter, "n_#{kind}", cb, nil, []])
        assert result.kind == kind
      end
    end
  end

  describe "instrument opts" do
    test "unit + description + advisory pass through verbatim; nil → \"\" / []", %{meter: meter} do
      result =
        Otel.SDK.Metrics.Meter.create_counter(meter, "req",
          unit: "1",
          description: "Requests",
          advisory: [attributes: ["method", "status"]]
        )

      assert result.unit == "1"
      assert result.description == "Requests"
      assert result.advisory == [attributes: ["method", "status"]]

      nil_opts =
        Otel.SDK.Metrics.Meter.create_counter(meter, "nilopts", unit: nil, description: nil)

      assert nil_opts.unit == ""
      assert nil_opts.description == ""

      hist =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "dur",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      assert hist.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    # Spec metrics/api.md L196-L211 MUST: unit ≥63 chars,
    # description ≥1023 chars, both case-sensitive, BMP support.
    test "unit ≥63 chars / description ≥1023 chars / case-sensitive / BMP characters", %{
      meter: meter
    } do
      lower = Otel.SDK.Metrics.Meter.create_counter(meter, "bytes_lower", unit: "kb")
      upper = Otel.SDK.Metrics.Meter.create_counter(meter, "bytes_upper", unit: "kB")
      assert lower.unit == "kb"
      assert upper.unit == "kB"

      long_unit = String.duplicate("a", 63)
      long_desc = String.duplicate("d", 1023)

      result =
        Otel.SDK.Metrics.Meter.create_counter(meter, "long",
          unit: long_unit,
          description: long_desc
        )

      assert result.unit == long_unit
      assert result.description == long_desc

      bmp = "Request count — 요청 ★ €"
      bmp_result = Otel.SDK.Metrics.Meter.create_counter(meter, "bmp", description: bmp)
      assert bmp_result.description == bmp
    end
  end

  describe "duplicate detection (within and across scopes)" do
    test "same scope: identical → same struct; case-insensitive → first-seen name wins" do
      meter = meter_for()

      first = Otel.SDK.Metrics.Meter.create_counter(meter, "RequestCount", unit: "1")
      assert first == Otel.SDK.Metrics.Meter.create_counter(meter, "RequestCount", unit: "1")

      case_dup = Otel.SDK.Metrics.Meter.create_counter(meter, "requestcount", unit: "1")
      assert case_dup.name == "RequestCount"
    end

    test "different scopes are independent namespaces (same name, different kind)" do
      meter_a = meter_for("lib_a")
      meter_b = meter_for("lib_b")

      assert Otel.SDK.Metrics.Meter.create_counter(meter_a, "requests", []).kind == :counter

      assert Otel.SDK.Metrics.Meter.create_histogram(meter_b, "requests", []).kind ==
               :histogram
    end
  end

  describe "duplicate conflict resolution" do
    test "conflicting unit/description/kind/advisory all return first-seen instrument", %{
      meter: meter
    } do
      pairs = [
        # {first_args, second_fn, second_args}
        {{"desc_dup", [unit: "1", description: "alpha"]},
         &Otel.SDK.Metrics.Meter.create_counter/3, [unit: "1", description: "beta"]},
        {{"unit_dup", [unit: "1", description: "a"]}, &Otel.SDK.Metrics.Meter.create_counter/3,
         [unit: "ms", description: "a"]},
        {{"kind_dup", [unit: "1"]}, &Otel.SDK.Metrics.Meter.create_histogram/3, [unit: "1"]},
        {{"both_dup", [unit: "1"]}, &Otel.SDK.Metrics.Meter.create_histogram/3, [unit: "ms"]}
      ]

      for {{name, first_opts}, second_fn, second_opts} <- pairs do
        first = Otel.SDK.Metrics.Meter.create_counter(meter, name, first_opts)
        second = second_fn.(meter, name, second_opts)
        assert second == first
      end

      # Histogram-only advisory conflict — first advisory wins.
      hist1 =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "adv_dup",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      hist2 =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "adv_dup",
          advisory: [explicit_bucket_boundaries: [100, 200]]
        )

      assert hist2 == hist1
      assert hist2.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    # Spec metrics/sdk.md L917-L930 — duplicate registration emits a
    # warning naming the conflicting field; identical re-registration
    # is silent.
    test "logs warning on conflicting duplicate; silent on identical re-registration", %{
      meter: meter
    } do
      log_conflict =
        capture_log(fn ->
          Otel.SDK.Metrics.Meter.create_counter(meter, "warn_dup", unit: "1")
          Otel.SDK.Metrics.Meter.create_counter(meter, "warn_dup", unit: "ms")
        end)

      assert log_conflict =~ "duplicate instrument registration"
      assert log_conflict =~ "warn_dup"
      assert log_conflict =~ ":unit"

      log_identical =
        capture_log(fn ->
          Otel.SDK.Metrics.Meter.create_counter(meter, "noop_dup", unit: "1", description: "x")
          Otel.SDK.Metrics.Meter.create_counter(meter, "noop_dup", unit: "1", description: "x")
        end)

      refute log_identical =~ "duplicate instrument registration"
    end
  end

  describe "record/3" do
    test "uses default aggregation per kind; aggregates across attribute sets", %{meter: meter} do
      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "req", [])
      Otel.SDK.Metrics.Meter.record(counter, 5, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(counter, 3, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(counter, 1, %{"method" => "POST"})

      sum_dps = datapoints(meter, "req", Otel.SDK.Metrics.Aggregation.Sum)
      by_attr = Map.new(sum_dps, &{&1.attributes, &1.value})
      assert by_attr[%{"method" => "GET"}] == 8
      assert by_attr[%{"method" => "POST"}] == 1

      gauge = Otel.SDK.Metrics.Meter.create_gauge(meter, "temp", [])
      Otel.SDK.Metrics.Meter.record(gauge, 20, %{})
      Otel.SDK.Metrics.Meter.record(gauge, 25, %{})
      [dp] = datapoints(meter, "temp", Otel.SDK.Metrics.Aggregation.LastValue)
      assert dp.value == 25

      hist = Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", [])
      Otel.SDK.Metrics.Meter.record(hist, 50, %{})
      Otel.SDK.Metrics.Meter.record(hist, 150, %{})

      [dp] = datapoints(meter, "latency", Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram)
      assert dp.value.count == 2
      assert dp.value.sum == 200
      assert dp.value.min == 50
      assert dp.value.max == 150
    end

    test "record on an unregistered instrument is a no-op (returns :ok)", %{meter: meter} do
      cfg = config_of(meter)

      ghost = %Otel.API.Metrics.Instrument{
        meter: meter,
        name: "ghost",
        kind: :counter,
        scope: cfg.scope
      }

      assert :ok == Otel.SDK.Metrics.Meter.record(ghost, 1, %{})
    end
  end

  describe "callback registration + run_callbacks" do
    test "inline callback (create_*/5) and register_callback/5 both feed the right instrument",
         %{meter: meter} do
      cfg = config_of(meter)

      cb = fn _args ->
        [%Otel.API.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}]
      end

      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])
      assert :ets.tab2list(cfg.callbacks_tab) != []

      Otel.SDK.Metrics.Meter.run_callbacks(cfg)

      [%{value: 42, attributes: %{"host" => "a"}}] =
        datapoints(meter, "cpu", Otel.SDK.Metrics.Aggregation.LastValue)

      assert :ok == Otel.SDK.Metrics.Meter.run_callbacks(config_of(meter_for("empty")))
    end

    test "register_callback/5 returns a tagged handle; unregister_callback removes it",
         %{meter: meter} do
      inst = Otel.SDK.Metrics.Meter.create_observable_counter(meter, "regd", [])
      cb = fn _args -> [%Otel.API.Metrics.Measurement{value: 1}] end

      reg = Otel.API.Metrics.Meter.register_callback(meter, [inst], cb, nil, [])
      assert {Otel.SDK.Metrics.Meter, {ref, _}} = reg
      assert is_reference(ref)

      cfg = config_of(meter)
      before_count = length(:ets.tab2list(cfg.callbacks_tab))

      assert :ok = Otel.API.Metrics.Meter.unregister_callback(reg)
      assert length(:ets.tab2list(cfg.callbacks_tab)) < before_count
    end

    # Spec L1302-L1303 — multi-instrument callbacks return
    # [{instrument, measurement}] pairs; each measurement is routed
    # to its paired instrument only.
    test "multi-instrument callback routes paired measurements per instrument", %{meter: meter} do
      usage = Otel.SDK.Metrics.Meter.create_observable_counter(meter, "usage", [])
      pressure = Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "pressure", [])

      cb = fn _args ->
        [
          {usage, %Otel.API.Metrics.Measurement{value: 42, attributes: %{"id" => "a"}}},
          {pressure, %Otel.API.Metrics.Measurement{value: 1013, attributes: %{"id" => "a"}}}
        ]
      end

      Otel.API.Metrics.Meter.register_callback(meter, [usage, pressure], cb, nil, [])
      Otel.SDK.Metrics.Meter.run_callbacks(config_of(meter))

      [u_dp] = datapoints(meter, "usage", Otel.SDK.Metrics.Aggregation.Sum)
      [p_dp] = datapoints(meter, "pressure", Otel.SDK.Metrics.Aggregation.LastValue)

      assert u_dp.value == 42
      assert p_dp.value == 1013
    end
  end

  describe "cardinality limits" do
    test "default aggregation_cardinality_limit is 2000", %{meter: meter} do
      cfg = config_of(meter)
      Otel.SDK.Metrics.Meter.create_counter(meter, "card_test", [])

      [{_, stream}] = :ets.lookup(cfg.streams_tab, {cfg.scope, "card_test"})
      assert stream.aggregation_cardinality_limit == 2000
    end
  end

  describe "enabled?/2 — always true (no Drop aggregation paths without Views)" do
    test "registered instrument", %{meter: meter} do
      assert true ==
               Otel.SDK.Metrics.Meter.enabled?(
                 Otel.SDK.Metrics.Meter.create_counter(meter, "active", []),
                 []
               )
    end

    test "unregistered instrument", %{meter: meter} do
      cfg = config_of(meter)

      ghost = %Otel.API.Metrics.Instrument{
        meter: meter,
        name: "ghost",
        kind: :counter,
        scope: cfg.scope
      }

      assert Otel.SDK.Metrics.Meter.enabled?(ghost, [])
    end
  end
end
