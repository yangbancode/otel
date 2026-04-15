defmodule Otel.SDK.Metrics.MetricProducerTest.TestProducer do
  @behaviour Otel.SDK.Metrics.MetricProducer

  @impl true
  def produce(_config) do
    {:ok,
     [
       %{
         name: "external_metric",
         description: "From external source",
         unit: "1",
         scope: %Otel.API.InstrumentationScope{name: "external"},
         resource: Otel.SDK.Resource.create(%{}),
         kind: :counter,
         datapoints: [
           %{attributes: %{}, value: 100, start_time: 1000, time: 2000}
         ]
       }
     ]}
  end
end

defmodule Otel.SDK.Metrics.MetricProducerTest do
  use ExUnit.Case, async: true

  describe "behaviour" do
    test "produce returns metrics" do
      assert {:ok, [metric]} =
               Otel.SDK.Metrics.MetricProducerTest.TestProducer.produce(%{})

      assert metric.name == "external_metric"
      assert metric.kind == :counter
    end

    test "produce can return error" do
      defmodule FailProducer do
        @behaviour Otel.SDK.Metrics.MetricProducer
        @impl true
        def produce(_config), do: {:error, :unavailable}
      end

      assert {:error, :unavailable} == FailProducer.produce(%{})
    end
  end
end
