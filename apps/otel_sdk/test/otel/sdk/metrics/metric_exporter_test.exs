defmodule Otel.SDK.Metrics.MetricExporterTest.TestExporter do
  @behaviour Otel.SDK.Metrics.MetricExporter

  @impl true
  def init(config), do: {:ok, config}

  @impl true
  def export(_metrics, _state), do: :ok

  @impl true
  def force_flush(_state), do: :ok

  @impl true
  def shutdown(_state), do: :ok
end

defmodule Otel.SDK.Metrics.MetricExporterTest do
  use ExUnit.Case, async: true

  describe "behaviour" do
    test "test exporter implements all callbacks" do
      assert {:ok, state} =
               Otel.SDK.Metrics.MetricExporterTest.TestExporter.init(%{})

      assert :ok ==
               Otel.SDK.Metrics.MetricExporterTest.TestExporter.export([], state)

      assert :ok ==
               Otel.SDK.Metrics.MetricExporterTest.TestExporter.force_flush(state)

      assert :ok ==
               Otel.SDK.Metrics.MetricExporterTest.TestExporter.shutdown(state)
    end

    test "init can return :ignore" do
      defmodule IgnoreExporter do
        @behaviour Otel.SDK.Metrics.MetricExporter
        @impl true
        def init(_config), do: :ignore
        @impl true
        def export(_metrics, _state), do: :ok
        @impl true
        def force_flush(_state), do: :ok
        @impl true
        def shutdown(_state), do: :ok
      end

      assert :ignore == IgnoreExporter.init(%{})
    end
  end
end
