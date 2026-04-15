defmodule Otel.SDK.Metrics.MetricReaderTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})
    {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "test_lib")
    meter = {Otel.SDK.Metrics.Meter, config}

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{meter: meter, config: config, provider: pid}
  end

  describe "collect/1" do
    test "returns empty when no instruments", %{config: config} do
      assert [] == Otel.SDK.Metrics.MetricReader.collect(config)
    end

    test "collects counter data", %{meter: meter, config: config} do
      Otel.SDK.Metrics.Meter.create_counter(meter, "requests", unit: "1")
      Otel.SDK.Metrics.Meter.record(meter, "requests", 5, %{method: "GET"})
      Otel.SDK.Metrics.Meter.record(meter, "requests", 3, %{method: "GET"})

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert [metric] = metrics
      assert metric.name == "requests"
      assert metric.unit == "1"
      assert metric.kind == :counter
      assert [dp] = metric.datapoints
      assert dp.value == 8
      assert dp.attributes == %{method: "GET"}
    end

    test "collects gauge data via callback", %{meter: meter, config: config} do
      cb = fn _args -> [{42, %{host: "a"}}] end
      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert [metric] = metrics
      assert metric.name == "cpu"
      assert [dp] = metric.datapoints
      assert dp.value == 42
    end

    test "collects histogram data", %{meter: meter, config: config} do
      Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", unit: "ms")
      Otel.SDK.Metrics.Meter.record(meter, "latency", 50, %{})
      Otel.SDK.Metrics.Meter.record(meter, "latency", 150, %{})

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert [metric] = metrics
      assert metric.name == "latency"
      assert [dp] = metric.datapoints
      assert dp.value.count == 2
      assert dp.value.sum == 200
    end

    test "collects multiple instruments", %{meter: meter, config: config} do
      Otel.SDK.Metrics.Meter.create_counter(meter, "req", [])
      Otel.SDK.Metrics.Meter.create_gauge(meter, "temp", [])
      Otel.SDK.Metrics.Meter.record(meter, "req", 1, %{})
      Otel.SDK.Metrics.Meter.record(meter, "temp", 22, %{})

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      assert length(metrics) == 2
      names = Enum.map(metrics, & &1.name) |> Enum.sort()
      assert names == ["req", "temp"]
    end

    test "includes resource in metric", %{meter: meter, config: config} do
      Otel.SDK.Metrics.Meter.create_counter(meter, "r", [])
      Otel.SDK.Metrics.Meter.record(meter, "r", 1, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert %Otel.SDK.Resource{} = metric.resource
    end

    test "includes scope in metric", %{meter: meter, config: config} do
      Otel.SDK.Metrics.Meter.create_counter(meter, "s", [])
      Otel.SDK.Metrics.Meter.record(meter, "s", 1, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.scope.name == "test_lib"
    end
  end
end
