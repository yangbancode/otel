defmodule Otel.API.Metrics.MeterProviderTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    :ok
  end

  describe "get_provider/0 and set_provider/1" do
    test "returns nil when no provider is set" do
      assert Otel.API.Metrics.MeterProvider.get_provider() == nil
    end

    test "returns the set provider" do
      Otel.API.Metrics.MeterProvider.set_provider(SomeProvider)
      assert Otel.API.Metrics.MeterProvider.get_provider() == SomeProvider
    end
  end

  describe "get_meter/1,2,3,4" do
    test "returns noop meter when no SDK installed" do
      {module, _config} = Otel.API.Metrics.MeterProvider.get_meter("my_lib")
      assert module == Otel.API.Metrics.Meter.Noop
    end

    test "returns same meter for same name" do
      meter1 = Otel.API.Metrics.MeterProvider.get_meter("my_lib")
      meter2 = Otel.API.Metrics.MeterProvider.get_meter("my_lib")
      assert meter1 == meter2
    end

    test "accepts version and schema_url" do
      meter = Otel.API.Metrics.MeterProvider.get_meter("my_lib", "1.0.0", "https://example.com")
      assert {Otel.API.Metrics.Meter.Noop, []} == meter
    end

    test "accepts attributes" do
      meter =
        Otel.API.Metrics.MeterProvider.get_meter("my_lib", "1.0.0", nil, %{key: "val"})

      assert {Otel.API.Metrics.Meter.Noop, []} == meter
    end

    test "returns working meter for nil name with warning" do
      {module, _config} = Otel.API.Metrics.MeterProvider.get_meter(nil)
      assert module == Otel.API.Metrics.Meter.Noop
    end

    test "returns working meter for empty name with warning" do
      {module, _config} = Otel.API.Metrics.MeterProvider.get_meter("")
      assert module == Otel.API.Metrics.Meter.Noop
    end

    test "caches meter in persistent_term" do
      meter1 = Otel.API.Metrics.MeterProvider.get_meter("cached_lib")
      meter2 = Otel.API.Metrics.MeterProvider.get_meter("cached_lib")
      assert meter1 === meter2
    end

    test "different attributes share the same cache entry" do
      meter1 = Otel.API.Metrics.MeterProvider.get_meter("lib", "1.0", nil, %{env: "prod"})
      meter2 = Otel.API.Metrics.MeterProvider.get_meter("lib", "1.0", nil, %{env: "staging"})
      assert meter1 === meter2
    end
  end

  describe "scope/1,2,3,4" do
    test "creates InstrumentationScope with name" do
      scope = Otel.API.Metrics.MeterProvider.scope("my_lib")

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "",
               schema_url: nil,
               attributes: %{}
             } == scope
    end

    test "creates InstrumentationScope with all fields" do
      scope =
        Otel.API.Metrics.MeterProvider.scope("my_lib", "1.0.0", "https://example.com", %{
          "key" => "val"
        })

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com",
               attributes: %{"key" => "val"}
             } == scope
    end
  end
end
