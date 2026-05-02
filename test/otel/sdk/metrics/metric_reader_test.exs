defmodule Otel.SDK.Metrics.MetricReaderTest do
  use ExUnit.Case, async: false

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)
  end

  defp meter_config(scope_name \\ "test_lib") do
    {_mod, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.API.InstrumentationScope{name: scope_name}
      )

    config
  end

  defp meter(config), do: {Otel.SDK.Metrics.Meter, config}

  setup do
    restart_sdk(metrics: [readers: []])
    config = meter_config()
    %{config: config, meter: meter(config)}
  end

  describe "collect/1 — instrument kinds" do
    test "no instruments → []", %{config: config} do
      assert [] = Otel.SDK.Metrics.MetricReader.collect(config)
    end

    test "counter accumulates per attribute set; metric carries name/unit/kind/scope/resource",
         %{config: config, meter: meter} do
      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "requests", unit: "1")
      Otel.SDK.Metrics.Meter.record(counter, 5, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(counter, 3, %{"method" => "GET"})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)

      assert metric.name == "requests"
      assert metric.unit == "1"
      assert metric.kind == :counter
      assert metric.scope.name == "test_lib"
      assert %Otel.SDK.Resource{} = metric.resource

      [dp] = metric.datapoints
      assert dp.value == 8
      assert dp.attributes == %{"method" => "GET"}
    end

    test "histogram aggregates count + sum; observable callback feeds gauge value",
         %{config: config, meter: meter} do
      hist = Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", unit: "ms")
      Otel.SDK.Metrics.Meter.record(hist, 50, %{})
      Otel.SDK.Metrics.Meter.record(hist, 150, %{})

      cb = fn _ -> [%Otel.API.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}] end
      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])

      metrics = Otel.SDK.Metrics.MetricReader.collect(config)
      by_name = Map.new(metrics, &{&1.name, &1})

      assert [%{value: %{count: 2, sum: 200}}] = by_name["latency"].datapoints
      assert [%{value: 42}] = by_name["cpu"].datapoints
    end

    test "sync + async + multiple instruments collect in one pass",
         %{config: config, meter: meter} do
      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "req", [])
      gauge = Otel.SDK.Metrics.Meter.create_gauge(meter, "temp", [])
      Otel.SDK.Metrics.Meter.record(counter, 1, %{})
      Otel.SDK.Metrics.Meter.record(gauge, 22, %{})

      names = Otel.SDK.Metrics.MetricReader.collect(config) |> Enum.map(& &1.name) |> Enum.sort()
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
      counter = Otel.SDK.Metrics.Meter.create_counter(meter(config), "sampled", [])
      Otel.SDK.Metrics.Meter.record(counter, 42, %{"method" => "GET"})

      [%{datapoints: [dp]}] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert hd(dp.exemplars).value == 42

      restart_sdk(metrics: [readers: [], exemplar_filter: :always_off])
      config2 = meter_config()
      counter2 = Otel.SDK.Metrics.Meter.create_counter(meter(config2), "not_sampled", [])
      Otel.SDK.Metrics.Meter.record(counter2, 1, %{})

      [%{datapoints: [dp2]}] = Otel.SDK.Metrics.MetricReader.collect(config2)
      assert dp2.exemplars == []
    end

    test "reservoirs reset between collect calls" do
      restart_sdk(metrics: [readers: [], exemplar_filter: :always_on])
      config = meter_config()
      counter = Otel.SDK.Metrics.Meter.create_counter(meter(config), "reset_test", [])

      Otel.SDK.Metrics.Meter.record(counter, 1, %{})
      _ = Otel.SDK.Metrics.MetricReader.collect(config)

      Otel.SDK.Metrics.Meter.record(counter, 2, %{})
      [%{datapoints: [dp]}] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert hd(dp.exemplars).value == 2
    end

    test "View attribute filtering moves dropped keys onto the exemplar's filtered_attributes" do
      restart_sdk(metrics: [readers: [], exemplar_filter: :always_on])
      provider = Otel.SDK.Metrics.MeterProvider

      Otel.SDK.Metrics.MeterProvider.add_view(
        provider,
        %{name: "attr_test"},
        %{attribute_keys: {:include, ["method"]}}
      )

      config = meter_config("lib")
      counter = Otel.SDK.Metrics.Meter.create_counter(meter(config), "attr_test", [])
      Otel.SDK.Metrics.Meter.record(counter, 1, %{"method" => "GET", "path" => "/api"})

      [%{datapoints: [dp]}] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert dp.attributes == %{"method" => "GET"}
      assert hd(dp.exemplars).filtered_attributes == %{"path" => "/api"}
    end

    test "config without :exemplars_tab — collect runs but datapoints carry no :exemplars",
         %{config: config, meter: meter} do
      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "no_ex", [])
      Otel.SDK.Metrics.Meter.record(counter, 5, %{})

      [%{datapoints: [dp]}] =
        Otel.SDK.Metrics.MetricReader.collect(Map.delete(config, :exemplars_tab))

      assert dp.value == 5
      refute Map.has_key?(dp, :exemplars)
    end
  end
end
