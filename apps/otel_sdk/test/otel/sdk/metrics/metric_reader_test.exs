defmodule Otel.SDK.Metrics.MetricReaderTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

    {_mod, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{
        name: "test_lib"
      })

    meter = {Otel.SDK.Metrics.Meter, config}

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    %{meter: meter, config: config, provider: pid}
  end

  describe "collect/1" do
    test "returns empty when no instruments", %{config: config} do
      assert [] == Otel.SDK.Metrics.MetricReader.collect(config)
    end

    test "collects counter data", %{meter: meter, config: config} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "requests", unit: "1")
      Otel.SDK.Metrics.Meter.record(instrument, 5, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(instrument, 3, %{"method" => "GET"})

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert [metric] = metrics
      assert metric.name == "requests"
      assert metric.unit == "1"
      assert metric.kind == :counter
      assert [dp] = metric.datapoints
      assert dp.value == 8
      assert dp.attributes == %{"method" => "GET"}
    end

    test "collects gauge data via callback", %{meter: meter, config: config} do
      cb = fn _args -> [Otel.API.Metrics.Measurement.new(42, %{"host" => "a"})] end
      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert [metric] = metrics
      assert metric.name == "cpu"
      assert [dp] = metric.datapoints
      assert dp.value == 42
    end

    test "collects histogram data", %{meter: meter, config: config} do
      instrument = Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", unit: "ms")
      Otel.SDK.Metrics.Meter.record(instrument, 50, %{})
      Otel.SDK.Metrics.Meter.record(instrument, 150, %{})

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert [metric] = metrics
      assert metric.name == "latency"
      assert [dp] = metric.datapoints
      assert dp.value.count == 2
      assert dp.value.sum == 200
    end

    test "collects multiple instruments", %{meter: meter, config: config} do
      instrument_req = Otel.SDK.Metrics.Meter.create_counter(meter, "req", [])
      instrument_temp = Otel.SDK.Metrics.Meter.create_gauge(meter, "temp", [])
      Otel.SDK.Metrics.Meter.record(instrument_req, 1, %{})
      Otel.SDK.Metrics.Meter.record(instrument_temp, 22, %{})

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert length(metrics) == 2
      names = Enum.map(metrics, & &1.name) |> Enum.sort()
      assert names == ["req", "temp"]
    end

    test "includes resource in metric", %{meter: meter, config: config} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "r", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert %Otel.SDK.Resource{} = metric.resource
    end

    test "includes scope in metric", %{meter: meter, config: config} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "s", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.scope.name == "test_lib"
    end

    test "datapoints include exemplars list", %{meter: meter, config: config} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "ex_counter", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp] = metric.datapoints
      assert Map.has_key?(dp, :exemplars)
      assert is_list(dp.exemplars)
    end

    test "exemplars collected with always_on filter" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(config: %{exemplar_filter: :always_on})

      {_mod, config} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: "lib"})

      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "sampled", [])
      Otel.SDK.Metrics.Meter.record(instrument, 42, %{"method" => "GET"})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp] = metric.datapoints
      assert dp.exemplars != []
      assert hd(dp.exemplars).value == 42
    end

    test "no exemplars with always_off filter" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(config: %{exemplar_filter: :always_off})

      {_mod, config} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: "lib"})

      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "not_sampled", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp] = metric.datapoints
      assert dp.exemplars == []
    end

    test "exemplars reset after collect" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(config: %{exemplar_filter: :always_on})

      {_mod, config} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: "lib"})

      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "reset_test", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{})

      [_] = Otel.SDK.Metrics.MetricReader.collect(config)

      Otel.SDK.Metrics.Meter.record(instrument, 2, %{})
      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp] = metric.datapoints
      assert hd(dp.exemplars).value == 2
    end

    test "collects without exemplars_tab in config", %{meter: meter, config: config} do
      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "no_ex", [])
      Otel.SDK.Metrics.Meter.record(instrument, 5, %{})

      no_exemplar_config = Map.delete(config, :exemplars_tab)
      [metric] = Otel.SDK.Metrics.MetricReader.collect(no_exemplar_config)
      [dp] = metric.datapoints
      assert dp.value == 5
      refute Map.has_key?(dp, :exemplars)
    end

    test "exemplar retains dropped attributes" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(config: %{exemplar_filter: :always_on})

      Otel.SDK.Metrics.MeterProvider.add_view(
        pid,
        %{name: "attr_test"},
        %{attribute_keys: {:include, ["method"]}}
      )

      {_mod, config} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: "lib"})

      meter = {Otel.SDK.Metrics.Meter, config}

      instrument = Otel.SDK.Metrics.Meter.create_counter(meter, "attr_test", [])
      Otel.SDK.Metrics.Meter.record(instrument, 1, %{"method" => "GET", "path" => "/api"})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp] = metric.datapoints
      assert dp.attributes == %{"method" => "GET"}
      exemplar = hd(dp.exemplars)
      assert exemplar.filtered_attributes == %{"path" => "/api"}
    end
  end
end
