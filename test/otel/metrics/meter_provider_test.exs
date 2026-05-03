defmodule Otel.Metrics.MeterProviderTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()
    :ok
  end

  describe "init/0 + persistent_term state" do
    test "seeds resource and exemplar_filter" do
      config = Otel.Metrics.MeterProvider.config()
      assert %Otel.Resource{} = config.resource
      assert config.exemplar_filter == :trace_based
      assert config.shut_down == false
    end

    test "resource/0 returns the seeded resource" do
      assert %Otel.Resource{} = Otel.Metrics.MeterProvider.resource()
    end

    test "respects custom resource via Application env" do
      custom = Otel.Resource.create(%{"service.name" => "test"})
      Application.put_env(:otel, :resource, %{"service.name" => "test"})
      on_exit(fn -> Application.delete_env(:otel, :resource) end)

      Otel.TestSupport.restart_with()

      %Otel.Metrics.Meter{config: %{resource: resource}} =
        Otel.Metrics.MeterProvider.get_meter()

      assert resource.attributes["service.name"] == custom.attributes["service.name"]
    end
  end

  describe "get_meter/0" do
    test "returns %Meter{} struct carrying the hardcoded SDK scope and resource" do
      %Otel.Metrics.Meter{config: config} = Otel.Metrics.MeterProvider.get_meter()

      assert %Otel.InstrumentationScope{name: "otel"} = config.scope
      assert %Otel.Resource{} = config.resource
      assert config.resource.attributes["telemetry.sdk.name"] == "otel"
    end
  end

  describe "shutdown/1 + force_flush/1" do
    test "first shutdown :ok; subsequent → :already_shutdown" do
      assert :ok = Otel.Metrics.MeterProvider.shutdown()
      assert {:error, :already_shutdown} = Otel.Metrics.MeterProvider.shutdown()
      assert {:error, :already_shutdown} = Otel.Metrics.MeterProvider.force_flush()
    end

    test "after shutdown, get_meter returns a degenerate Meter" do
      :ok = Otel.Metrics.MeterProvider.shutdown()

      assert %Otel.Metrics.Meter{} = Otel.Metrics.MeterProvider.get_meter()
    end

    test "facades stay graceful when no provider state has been seeded" do
      Otel.TestSupport.stop_all()

      assert :ok = Otel.Metrics.MeterProvider.force_flush()
      assert :ok = Otel.Metrics.MeterProvider.shutdown()
      assert %Otel.Resource{} = Otel.Metrics.MeterProvider.resource()
      assert %{} = Otel.Metrics.MeterProvider.config()
    end
  end
end
