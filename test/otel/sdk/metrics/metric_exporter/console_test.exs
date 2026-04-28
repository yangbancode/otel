defmodule Otel.SDK.Metrics.MetricExporter.ConsoleTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @scope %Otel.API.InstrumentationScope{name: "test_lib", version: "1.0.0"}
  @resource Otel.SDK.Resource.create(%{"service.name" => "test"})

  defp render(metrics),
    do: capture_io(fn -> Otel.SDK.Metrics.MetricExporter.Console.export(metrics, %{}) end)

  test "init/1 + shutdown/1 + force_flush/1 round-trip" do
    assert {:ok, %{}} = Otel.SDK.Metrics.MetricExporter.Console.init(%{})
    assert :ok = Otel.SDK.Metrics.MetricExporter.Console.shutdown(%{})
    assert :ok = Otel.SDK.Metrics.MetricExporter.Console.force_flush(%{})
  end

  describe "export/2" do
    test "renders a counter metric — name, kind, scope, value" do
      metric = %{
        name: "requests",
        description: "Total requests",
        unit: "1",
        scope: @scope,
        resource: @resource,
        kind: :counter,
        datapoints: [
          %{attributes: %{"method" => "GET"}, value: 42, start_time: 1000, time: 2000}
        ]
      }

      output = render([metric])

      assert output =~ "requests"
      assert output =~ "counter"
      assert output =~ "test_lib"
      assert output =~ "42"
    end

    test "renders a histogram metric — name, kind, count + sum from the value map" do
      metric = %{
        name: "latency",
        description: "Request latency",
        unit: "ms",
        scope: @scope,
        resource: @resource,
        kind: :histogram,
        datapoints: [
          %{
            attributes: %{},
            value: %{
              bucket_counts: [1, 2, 0, 1],
              sum: 250,
              count: 4,
              min: 5,
              max: 200,
              boundaries: [10, 50, 100]
            },
            start_time: 1000,
            time: 2000
          }
        ]
      }

      output = render([metric])

      assert output =~ "latency"
      assert output =~ "histogram"
      assert output =~ "count=4"
      assert output =~ "sum=250"
    end

    test "renders multiple datapoints (one per attribute set)" do
      metric = %{
        name: "temp",
        description: "Temperature",
        unit: "C",
        scope: @scope,
        resource: @resource,
        kind: :gauge,
        datapoints: [
          %{attributes: %{"host" => "a"}, value: 20, start_time: 1000, time: 2000},
          %{attributes: %{"host" => "b"}, value: 25, start_time: 1000, time: 2000}
        ]
      }

      output = render([metric])

      assert output =~ ~s|"host" => "a"|
      assert output =~ ~s|"host" => "b"|
    end
  end
end
