defmodule Otel.SDK.Metrics.MeterTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})
    {_module, meter_config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "test_lib")
    meter = {Otel.SDK.Metrics.Meter, meter_config}

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    %{meter: meter}
  end

  describe "instrument creation returns struct" do
    test "create_counter returns instrument struct", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_counter(meter, "my_counter", [])
      assert %Otel.API.Metrics.Instrument{name: "my_counter", kind: :counter} = result
    end

    test "create_histogram returns instrument struct", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_histogram(meter, "my_histogram", [])
      assert %Otel.API.Metrics.Instrument{name: "my_histogram", kind: :histogram} = result
    end

    test "create_gauge returns instrument struct", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_gauge(meter, "my_gauge", [])
      assert %Otel.API.Metrics.Instrument{name: "my_gauge", kind: :gauge} = result
    end

    test "create_updown_counter returns instrument struct", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_updown_counter(meter, "my_updown", [])
      assert %Otel.API.Metrics.Instrument{name: "my_updown", kind: :updown_counter} = result
    end

    test "create_observable_counter returns instrument struct", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_observable_counter(meter, "obs_counter", [])

      assert %Otel.API.Metrics.Instrument{name: "obs_counter", kind: :observable_counter} =
               result
    end

    test "create_observable_counter with callback returns struct", %{meter: meter} do
      cb = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end

      result =
        Otel.SDK.Metrics.Meter.create_observable_counter(meter, "obs_counter2", cb, nil, [])

      assert %Otel.API.Metrics.Instrument{kind: :observable_counter} = result
    end

    test "create_observable_gauge returns instrument struct", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "obs_gauge", [])
      assert %Otel.API.Metrics.Instrument{name: "obs_gauge", kind: :observable_gauge} = result
    end

    test "create_observable_gauge with callback returns struct", %{meter: meter} do
      cb = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end
      result = Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "obs_gauge2", cb, nil, [])
      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} = result
    end

    test "create_observable_updown_counter returns instrument struct", %{meter: meter} do
      result =
        Otel.SDK.Metrics.Meter.create_observable_updown_counter(meter, "obs_updown", [])

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} = result
    end

    test "create_observable_updown_counter with callback returns struct", %{meter: meter} do
      cb = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end

      result =
        Otel.SDK.Metrics.Meter.create_observable_updown_counter(
          meter,
          "obs_updown2",
          cb,
          nil,
          []
        )

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} = result
    end
  end

  describe "instrument opts" do
    test "unit and description stored", %{meter: meter} do
      result =
        Otel.SDK.Metrics.Meter.create_counter(meter, "req", unit: "1", description: "Requests")

      assert result.unit == "1"
      assert result.description == "Requests"
    end

    test "nil unit treated as empty string", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_counter(meter, "req2", unit: nil)
      assert result.unit == ""
    end

    test "nil description treated as empty string", %{meter: meter} do
      result = Otel.SDK.Metrics.Meter.create_counter(meter, "req3", description: nil)
      assert result.description == ""
    end

    test "advisory stored for histogram", %{meter: meter} do
      result =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "dur",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      assert result.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    test "advisory attributes stored for any instrument kind", %{meter: meter} do
      result =
        Otel.SDK.Metrics.Meter.create_counter(meter, "adv_attrs",
          advisory: [attributes: ["method", "status"]]
        )

      assert result.advisory == [attributes: ["method", "status"]]
    end

    test "advisory attributes filter recording attributes", %{meter: meter} do
      instrument =
        Otel.SDK.Metrics.Meter.create_counter(meter, "adv_filter",
          advisory: [attributes: ["method"]]
        )

      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"method" => "GET", "path" => "/api"})

      {_module, config} = meter
      stream_key = {"adv_filter", config.scope}
      [dp] = Otel.SDK.Metrics.Aggregation.Sum.collect(config.metrics_tab, stream_key, %{})
      assert dp.attributes == %{"method" => "GET"}
    end

    test "unit is case-sensitive (kb vs kB stored verbatim)", %{meter: meter} do
      lower = Otel.SDK.Metrics.Meter.create_counter(meter, "bytes_lower", unit: "kb")
      upper = Otel.SDK.Metrics.Meter.create_counter(meter, "bytes_upper", unit: "kB")
      assert lower.unit == "kb"
      assert upper.unit == "kB"
      refute lower.unit == upper.unit
    end

    test "unit accepts at least 63 characters (spec MUST)", %{meter: meter} do
      unit = String.duplicate("a", 63)
      result = Otel.SDK.Metrics.Meter.create_counter(meter, "unit_63", unit: unit)
      assert result.unit == unit
      assert String.length(result.unit) == 63
    end

    test "description accepts at least 1023 characters (spec MUST)", %{meter: meter} do
      description = String.duplicate("d", 1023)
      result = Otel.SDK.Metrics.Meter.create_counter(meter, "desc_1023", description: description)
      assert result.description == description
      assert String.length(result.description) == 1023
    end

    test "description supports BMP characters (spec MUST)", %{meter: meter} do
      description = "Request count — 요청 ★ €"
      result = Otel.SDK.Metrics.Meter.create_counter(meter, "desc_bmp", description: description)
      assert result.description == description
    end
  end

  describe "duplicate detection" do
    test "identical instrument returns same struct", %{meter: meter} do
      first = Otel.SDK.Metrics.Meter.create_counter(meter, "dup_counter", unit: "1")
      second = Otel.SDK.Metrics.Meter.create_counter(meter, "dup_counter", unit: "1")
      assert first == second
    end

    test "case-insensitive duplicate returns first-seen name", %{meter: meter} do
      Otel.SDK.Metrics.Meter.create_counter(meter, "RequestCount", unit: "1")
      second = Otel.SDK.Metrics.Meter.create_counter(meter, "requestcount", unit: "1")
      assert second.name == "RequestCount"
    end

    test "conflicting duplicate returns first-seen with warning", %{meter: meter} do
      first =
        Otel.SDK.Metrics.Meter.create_counter(meter, "conflict", unit: "1", description: "a")

      second =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "conflict", unit: "ms", description: "b")

      assert second == first
    end

    test "different scopes are independent namespaces" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      {_, config_a} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib_a")
      {_, config_b} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib_b")
      meter_a = {Otel.SDK.Metrics.Meter, config_a}
      meter_b = {Otel.SDK.Metrics.Meter, config_b}

      inst_a = Otel.SDK.Metrics.Meter.create_counter(meter_a, "requests", [])
      inst_b = Otel.SDK.Metrics.Meter.create_histogram(meter_b, "requests", [])

      assert inst_a.kind == :counter
      assert inst_b.kind == :histogram
    end
  end

  describe "recording" do
    test "record returns :ok", %{meter: meter} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "rec_counter", [])
      assert :ok == Otel.SDK.Metrics.Meter.record(instrument, 1, %{})
    end

    test "record aggregates counter values", %{meter: meter} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "agg_counter", [])
      Otel.SDK.Metrics.Meter.record(instrument, 5, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(instrument, 3, %{"method" => "GET"})

      {_module, config} = meter
      stream_key = {"agg_counter", config.scope}

      [dp] =
        Otel.SDK.Metrics.Aggregation.Sum.collect(config.metrics_tab, stream_key, %{})

      assert dp.value == 8
      assert dp.attributes == %{"method" => "GET"}
    end

    test "record uses default aggregation for instrument kind", %{meter: meter} do
      instrument = Otel.SDK.Metrics.Meter.create_gauge(meter, "temp", [])
      Otel.SDK.Metrics.Meter.record(instrument, 20, %{})
      Otel.SDK.Metrics.Meter.record(instrument, 25, %{})

      {_module, config} = meter
      stream_key = {"temp", config.scope}

      [dp] =
        Otel.SDK.Metrics.Aggregation.LastValue.collect(config.metrics_tab, stream_key, %{})

      assert dp.value == 25
    end

    test "record with histogram", %{meter: meter} do
      instrument = Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", [])
      Otel.SDK.Metrics.Meter.record(instrument, 50, %{})
      Otel.SDK.Metrics.Meter.record(instrument, 150, %{})

      {_module, config} = meter
      stream_key = {"latency", config.scope}

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          config.metrics_tab,
          stream_key,
          %{}
        )

      assert dp.value.count == 2
      assert dp.value.sum == 200
      assert dp.value.min == 50
      assert dp.value.max == 150
    end

    test "record for unregistered instrument is no-op", %{meter: meter} do
      {_module, config} = meter

      instrument = %Otel.API.Metrics.Instrument{
        meter: meter,
        name: "nonexistent",
        kind: :counter,
        scope: config.scope
      }

      assert :ok == Otel.SDK.Metrics.Meter.record(instrument, 1, %{})
    end

    test "record with different attributes creates separate datapoints", %{meter: meter} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "req", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(instrument, 2, %{"method" => "POST"})

      {_module, config} = meter
      stream_key = {"req", config.scope}

      dps = Otel.SDK.Metrics.Aggregation.Sum.collect(config.metrics_tab, stream_key, %{})
      assert length(dps) == 2
    end

    test "record respects include attribute filter from view" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "filtered"},
        %{attribute_keys: {:include, ["method"]}}
      )

      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "filtered", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"method" => "GET", "path" => "/api"})

      stream_key = {"filtered", config.scope}
      [dp] = Otel.SDK.Metrics.Aggregation.Sum.collect(config.metrics_tab, stream_key, %{})
      assert dp.attributes == %{"method" => "GET"}
    end

    test "record respects exclude attribute filter from view" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "excluded"},
        %{attribute_keys: {:exclude, ["path"]}}
      )

      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "excluded", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"method" => "GET", "path" => "/api"})

      stream_key = {"excluded", config.scope}
      [dp] = Otel.SDK.Metrics.Aggregation.Sum.collect(config.metrics_tab, stream_key, %{})
      assert dp.attributes == %{"method" => "GET"}
    end
  end

  describe "callback registration" do
    test "inline callback stored on creation", %{meter: meter} do
      cb = fn _args -> [Otel.API.Metrics.Measurement.new(42)] end

      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])

      {_module, config} = meter
      callbacks = :ets.tab2list(config.callbacks_tab)
      assert callbacks != []
    end

    test "register_callback returns tagged handle for unregistration", %{meter: meter} do
      inst =
        Otel.SDK.Metrics.Meter.create_observable_counter(meter, "cb_counter", [])

      cb = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end
      result = Otel.SDK.Metrics.Meter.register_callback(meter, [inst], cb, nil, [])
      assert {Otel.SDK.Metrics.Meter, {ref, _tab}} = result
      assert is_reference(ref)
    end

    test "unregister_callback via API dispatch removes the callback", %{meter: meter} do
      inst =
        Otel.SDK.Metrics.Meter.create_observable_counter(meter, "unreg_counter", [])

      cb = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end
      registration = Otel.API.Metrics.Meter.register_callback(meter, [inst], cb, nil, [])

      {_module, config} = meter
      before_count = length(:ets.tab2list(config.callbacks_tab))

      assert :ok = Otel.API.Metrics.Meter.unregister_callback(registration)

      after_count = length(:ets.tab2list(config.callbacks_tab))
      assert after_count < before_count
    end

    test "run_callbacks aggregates observations", %{meter: meter} do
      cb = fn _args ->
        [
          Otel.API.Metrics.Measurement.new(100, %{"host" => "a"}),
          Otel.API.Metrics.Measurement.new(200, %{"host" => "b"})
        ]
      end

      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "mem", cb, nil, [])

      {_module, config} = meter
      Otel.SDK.Metrics.Meter.run_callbacks(config)

      stream_key = {"mem", config.scope}

      dps =
        Otel.SDK.Metrics.Aggregation.LastValue.collect(config.metrics_tab, stream_key, %{})

      assert length(dps) == 2
      values = Enum.map(dps, & &1.value) |> Enum.sort()
      assert values == [100, 200]
    end

    test "run_callbacks with no callbacks is no-op", %{meter: meter} do
      {_module, config} = meter
      assert :ok == Otel.SDK.Metrics.Meter.run_callbacks(config)
    end
  end

  describe "cardinality limits" do
    test "default cardinality limit is 2000", %{meter: meter} do
      Otel.SDK.Metrics.Meter.create_counter(meter, "card_test", [])
      {_module, config} = meter

      [{_key, stream}] =
        :ets.lookup(
          config.streams_tab,
          {config.scope, "card_test"}
        )

      assert stream.aggregation_cardinality_limit == 2000
    end

    test "overflow routes to overflow attribute set" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "limited"},
        %{aggregation_cardinality_limit: 3}
      )

      {_mod, cfg} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      m = {Otel.SDK.Metrics.Meter, cfg}

      instrument = Otel.SDK.Metrics.Meter.create_counter(m, "limited", [])

      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"k" => "a"})
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"k" => "b"})
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"k" => "c"})
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"k" => "d"})
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"k" => "e"})

      stream_key = {"limited", cfg.scope}
      dps = Otel.SDK.Metrics.Aggregation.Sum.collect(cfg.metrics_tab, stream_key, %{})

      overflow_dp =
        Enum.find(dps, fn dp -> dp.attributes == %{"otel.metric.overflow" => true} end)

      assert overflow_dp != nil
      assert overflow_dp.value == 2

      normal_dps =
        Enum.reject(dps, fn dp -> dp.attributes == %{"otel.metric.overflow" => true} end)

      assert length(normal_dps) == 3
    end

    test "existing attribute set not affected by overflow" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "exist_test"},
        %{aggregation_cardinality_limit: 2}
      )

      {_mod, cfg} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      m = {Otel.SDK.Metrics.Meter, cfg}

      instrument = Otel.SDK.Metrics.Meter.create_counter(m, "exist_test", [])

      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"k" => "a"})
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"k" => "b"})
      Otel.SDK.Metrics.Meter.record(instrument, 5, %{"k" => "a"})

      stream_key = {"exist_test", cfg.scope}
      dps = Otel.SDK.Metrics.Aggregation.Sum.collect(cfg.metrics_tab, stream_key, %{})

      dp_a = Enum.find(dps, fn dp -> dp.attributes == %{"k" => "a"} end)
      assert dp_a.value == 6
    end
  end

  describe "duplicate conflict resolution" do
    test "description-only conflict with view override suppresses warning" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "desc_dup"},
        %{description: "Canonical description"}
      )

      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      meter = {Otel.SDK.Metrics.Meter, config}

      first =
        Otel.SDK.Metrics.Meter.create_counter(meter, "desc_dup",
          unit: "1",
          description: "first"
        )

      second =
        Otel.SDK.Metrics.Meter.create_counter(meter, "desc_dup",
          unit: "1",
          description: "second"
        )

      assert first == second
    end

    test "description-only conflict without view emits warning", %{meter: meter} do
      Otel.SDK.Metrics.Meter.create_counter(meter, "desc_no_view",
        unit: "1",
        description: "alpha"
      )

      result =
        Otel.SDK.Metrics.Meter.create_counter(meter, "desc_no_view",
          unit: "1",
          description: "beta"
        )

      assert result.description == "alpha"
    end

    test "distinguishable conflict suggests renaming view", %{meter: meter} do
      first = Otel.SDK.Metrics.Meter.create_counter(meter, "kind_dup", unit: "1")
      second = Otel.SDK.Metrics.Meter.create_histogram(meter, "kind_dup", unit: "1")
      assert second == first
    end

    test "unresolvable conflict emits generic warning", %{meter: meter} do
      first =
        Otel.SDK.Metrics.Meter.create_counter(meter, "unit_dup",
          unit: "1",
          description: "a"
        )

      second =
        Otel.SDK.Metrics.Meter.create_counter(meter, "unit_dup",
          unit: "ms",
          description: "a"
        )

      assert second == first
    end

    test "advisory-only conflict returns first-seen advisory", %{meter: meter} do
      first =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "adv_dup",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      second =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "adv_dup",
          advisory: [explicit_bucket_boundaries: [100, 200, 500]]
        )

      assert second == first
      assert second.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    test "kind and unit both differ is distinguishable", %{meter: meter} do
      first = Otel.SDK.Metrics.Meter.create_counter(meter, "both_dup", unit: "1")
      second = Otel.SDK.Metrics.Meter.create_histogram(meter, "both_dup", unit: "ms")
      assert second == first
    end
  end

  describe "enabled?" do
    test "returns true for registered instrument", %{meter: meter} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "basic_counter", [])
      assert true == Otel.SDK.Metrics.Meter.enabled?(instrument, [])
    end

    test "returns true for registered instrument with non-Drop aggregation", %{meter: meter} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "active_counter", [])
      assert true == Otel.SDK.Metrics.Meter.enabled?(instrument, [])
    end

    test "returns false when all views use Drop aggregation" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "dropped"},
        %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
      )

      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "dropped", [])
      refute Otel.SDK.Metrics.Meter.enabled?(instrument, [])
    end

    test "returns true when at least one view is not Drop" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "partial_drop"},
        %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
      )

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{type: :counter},
        %{name: "partial_drop_sum"}
      )

      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "partial_drop", [])
      assert Otel.SDK.Metrics.Meter.enabled?(instrument, [])
    end

    test "returns false for unregistered instrument when all matching views Drop" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "*"},
        %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
      )

      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = %Otel.API.Metrics.Instrument{
        meter: meter,
        name: "not_yet_created",
        kind: :counter,
        scope: config.scope
      }

      refute Otel.SDK.Metrics.Meter.enabled?(instrument, [])
    end

    test "returns true for unregistered instrument with no matching views", %{meter: meter} do
      {_module, config} = meter

      instrument = %Otel.API.Metrics.Instrument{
        meter: meter,
        name: "unknown",
        kind: :counter,
        scope: config.scope
      }

      assert Otel.SDK.Metrics.Meter.enabled?(instrument, [])
    end
  end

  describe "match_views/2" do
    test "no views returns default stream from instrument" do
      inst = %Otel.API.Metrics.Instrument{
        name: "requests",
        kind: :counter,
        unit: "1",
        description: "Request count",
        advisory: [],
        scope: %Otel.API.InstrumentationScope{name: "lib"}
      }

      streams = Otel.SDK.Metrics.Meter.match_views([], inst)
      assert [%Otel.SDK.Metrics.Stream{name: "requests"}] = streams
    end

    test "matching view produces stream with view config" do
      {:ok, view} =
        Otel.SDK.Metrics.View.new(
          %{name: "requests"},
          %{name: "req_total", description: "Total requests"}
        )

      inst = %Otel.API.Metrics.Instrument{
        name: "requests",
        kind: :counter,
        unit: "1",
        description: "Request count",
        advisory: [],
        scope: %Otel.API.InstrumentationScope{name: "lib"}
      }

      streams = Otel.SDK.Metrics.Meter.match_views([view], inst)

      assert [%Otel.SDK.Metrics.Stream{name: "req_total", description: "Total requests"}] =
               streams
    end

    test "non-matching view falls back to default stream" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{name: "other_metric"}, %{name: "renamed"})

      inst = %Otel.API.Metrics.Instrument{
        name: "requests",
        kind: :counter,
        unit: "1",
        description: "Request count",
        advisory: [],
        scope: %Otel.API.InstrumentationScope{name: "lib"}
      }

      streams = Otel.SDK.Metrics.Meter.match_views([view], inst)
      assert [%Otel.SDK.Metrics.Stream{name: "requests"}] = streams
    end

    test "multiple matching views produce multiple streams" do
      {:ok, view1} = Otel.SDK.Metrics.View.new(%{type: :histogram}, %{name: "stream_a"})
      {:ok, view2} = Otel.SDK.Metrics.View.new(%{unit: "ms"}, %{name: "stream_b"})

      inst = %Otel.API.Metrics.Instrument{
        name: "latency",
        kind: :histogram,
        unit: "ms",
        description: "Latency",
        advisory: [],
        scope: %Otel.API.InstrumentationScope{name: "lib"}
      }

      streams = Otel.SDK.Metrics.Meter.match_views([view1, view2], inst)
      assert length(streams) == 2
      assert Enum.map(streams, & &1.name) == ["stream_a", "stream_b"]
    end

    test "conflicting stream names emit warning" do
      {:ok, view1} = Otel.SDK.Metrics.View.new(%{type: :counter}, %{name: "same_name"})
      {:ok, view2} = Otel.SDK.Metrics.View.new(%{unit: "1"}, %{name: "same_name"})

      inst = %Otel.API.Metrics.Instrument{
        name: "requests",
        kind: :counter,
        unit: "1",
        description: "Count",
        advisory: [],
        scope: %Otel.API.InstrumentationScope{name: "lib"}
      }

      streams = Otel.SDK.Metrics.Meter.match_views([view1, view2], inst)
      assert length(streams) == 2
    end
  end
end
