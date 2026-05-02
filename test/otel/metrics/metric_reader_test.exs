defmodule Otel.Metrics.MetricReaderTest do
  use ExUnit.Case, async: false

  defp restart_sdk(env), do: Otel.TestSupport.restart_with(env)

  defp meter_config(scope_name \\ "test_lib") do
    %Otel.Metrics.Meter{config: config} =
      Otel.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: scope_name})

    config
  end

  defp meter(config), do: %Otel.Metrics.Meter{config: config}

  setup do
    restart_sdk(metrics: [readers: []])
    config = meter_config()
    %{config: config, meter: meter(config)}
  end

  describe "collect/1 — instrument kinds" do
    test "no instruments → []", %{config: config} do
      assert [] = Otel.Metrics.MetricReader.collect(config)
    end

    test "counter accumulates per attribute set; metric carries name/unit/kind/scope/resource",
         %{config: config, meter: meter} do
      counter = Otel.Metrics.Meter.create_counter(meter, "requests", unit: "1")
      Otel.Metrics.Meter.record(counter, 5, %{"method" => "GET"})
      Otel.Metrics.Meter.record(counter, 3, %{"method" => "GET"})

      [metric] = Otel.Metrics.MetricReader.collect(config)

      assert metric.name == "requests"
      assert metric.unit == "1"
      assert metric.kind == :counter
      assert metric.scope.name == "test_lib"
      assert %Otel.Resource{} = metric.resource

      [dp] = metric.datapoints
      assert dp.value == 8
      assert dp.attributes == %{"method" => "GET"}
    end

    test "histogram aggregates count + sum; observable callback feeds gauge value",
         %{config: config, meter: meter} do
      hist = Otel.Metrics.Meter.create_histogram(meter, "latency", unit: "ms")
      Otel.Metrics.Meter.record(hist, 50, %{})
      Otel.Metrics.Meter.record(hist, 150, %{})

      cb = fn _ -> [%Otel.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}] end
      Otel.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])

      metrics = Otel.Metrics.MetricReader.collect(config)
      by_name = Map.new(metrics, &{&1.name, &1})

      assert [%{value: %{count: 2, sum: 200}}] = by_name["latency"].datapoints
      assert [%{value: 42}] = by_name["cpu"].datapoints
    end

    test "sync + async + multiple instruments collect in one pass",
         %{config: config, meter: meter} do
      counter = Otel.Metrics.Meter.create_counter(meter, "req", [])
      gauge = Otel.Metrics.Meter.create_gauge(meter, "temp", [])
      Otel.Metrics.Meter.record(counter, 1, %{})
      Otel.Metrics.Meter.record(gauge, 22, %{})

      names = Otel.Metrics.MetricReader.collect(config) |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["req", "temp"]
    end
  end

  # Spec metrics/sdk.md L1374-L1389 — exemplar_filter (:always_on /
  # :always_off / :trace_based) gates whether reservoirs collect at
  # all; reservoirs reset between collect calls.
  describe "exemplars" do
    test ":always_on collects exemplars; :always_off yields []" do
      restart_sdk(metrics: [readers: [], exemplar_filter: :always_on])
      config = meter_config()
      counter = Otel.Metrics.Meter.create_counter(meter(config), "sampled", [])
      Otel.Metrics.Meter.record(counter, 42, %{"method" => "GET"})

      [%{datapoints: [dp]}] = Otel.Metrics.MetricReader.collect(config)
      assert hd(dp.exemplars).value == 42

      restart_sdk(metrics: [readers: [], exemplar_filter: :always_off])
      config2 = meter_config()
      counter2 = Otel.Metrics.Meter.create_counter(meter(config2), "not_sampled", [])
      Otel.Metrics.Meter.record(counter2, 1, %{})

      [%{datapoints: [dp2]}] = Otel.Metrics.MetricReader.collect(config2)
      assert dp2.exemplars == []
    end

    test "reservoirs reset between collect calls" do
      restart_sdk(metrics: [readers: [], exemplar_filter: :always_on])
      config = meter_config()
      counter = Otel.Metrics.Meter.create_counter(meter(config), "reset_test", [])

      Otel.Metrics.Meter.record(counter, 1, %{})
      _ = Otel.Metrics.MetricReader.collect(config)

      Otel.Metrics.Meter.record(counter, 2, %{})
      [%{datapoints: [dp]}] = Otel.Metrics.MetricReader.collect(config)
      assert hd(dp.exemplars).value == 2
    end

    test "config without :exemplars_tab — collect runs but datapoints carry no :exemplars",
         %{config: config, meter: meter} do
      counter = Otel.Metrics.Meter.create_counter(meter, "no_ex", [])
      Otel.Metrics.Meter.record(counter, 5, %{})

      [%{datapoints: [dp]}] =
        Otel.Metrics.MetricReader.collect(Map.delete(config, :exemplars_tab))

      assert dp.value == 5
      refute Map.has_key?(dp, :exemplars)
    end
  end
end
