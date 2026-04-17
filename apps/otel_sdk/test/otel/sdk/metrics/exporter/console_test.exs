defmodule Otel.SDK.Metrics.Exporter.ConsoleTest do
  use ExUnit.Case

  @scope %Otel.API.InstrumentationScope{name: "test_lib", version: "1.0.0"}
  @resource Otel.SDK.Resource.create(%{"service.name" => "test"})

  describe "init/1" do
    test "returns {:ok, config}" do
      assert {:ok, %{}} = Otel.SDK.Metrics.Exporter.Console.init(%{})
    end
  end

  describe "export/2" do
    test "prints counter metric to stdout" do
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

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok == Otel.SDK.Metrics.Exporter.Console.export([metric], %{})
        end)

      assert output =~ "requests"
      assert output =~ "counter"
      assert output =~ "test_lib"
      assert output =~ "42"
    end

    test "prints histogram metric to stdout" do
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

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok == Otel.SDK.Metrics.Exporter.Console.export([metric], %{})
        end)

      assert output =~ "latency"
      assert output =~ "histogram"
      assert output =~ "count=4"
      assert output =~ "sum=250"
    end

    test "prints multiple datapoints" do
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

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Otel.SDK.Metrics.Exporter.Console.export([metric], %{})
        end)

      assert output =~ "\"host\" => \"a\""
      assert output =~ "\"host\" => \"b\""
    end
  end

  describe "force_flush/1" do
    test "returns :ok" do
      assert :ok == Otel.SDK.Metrics.Exporter.Console.force_flush(%{})
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      assert :ok == Otel.SDK.Metrics.Exporter.Console.shutdown(%{})
    end
  end
end
