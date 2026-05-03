defmodule Otel.Metrics.MeterProviderTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()
    :ok
  end

  describe "config/0 introspection" do
    test "exposes resource (from app env) and the hardcoded meter config literals" do
      config = Otel.Metrics.MeterProvider.config()
      assert %Otel.Resource{} = config.resource
      assert config.exemplar_filter == :trace_based
      assert config.reader_id == :default_reader
      assert config.instruments_tab == :otel_instruments
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

  describe "introspection without provider state" do
    test "resource/0 falls back to Otel.Resource.default/0" do
      Otel.TestSupport.stop_all()

      assert %Otel.Resource{} = Otel.Metrics.MeterProvider.resource()
      assert %{} = Otel.Metrics.MeterProvider.config()
    end
  end
end
