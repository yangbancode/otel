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
      Otel.API.Metrics.MeterProvider.set_provider({SomeProvider, :opaque_state})
      assert Otel.API.Metrics.MeterProvider.get_provider() == {SomeProvider, :opaque_state}
    end
  end

  describe "get_meter/0,1" do
    test "returns noop meter when no SDK installed" do
      {module, _config} =
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert module == Otel.API.Metrics.Meter.Noop
    end

    test "returns noop meter with default empty scope when called with no args" do
      {module, _config} = Otel.API.Metrics.MeterProvider.get_meter()
      assert module == Otel.API.Metrics.Meter.Noop
    end

    test "returns same meter for equal scopes" do
      meter1 =
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "my_lib"})

      meter2 =
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert meter1 == meter2
    end

    test "scopes differing by any field produce distinct cache entries" do
      scope_a = %Otel.API.InstrumentationScope{name: "lib", attributes: %{"env" => "prod"}}
      scope_b = %Otel.API.InstrumentationScope{name: "lib", attributes: %{"env" => "staging"}}

      assert {Otel.API.Metrics.Meter.Noop, []} ==
               Otel.API.Metrics.MeterProvider.get_meter(scope_a)

      assert {Otel.API.Metrics.Meter.Noop, []} ==
               Otel.API.Metrics.MeterProvider.get_meter(scope_b)
    end

    test "caches meter in persistent_term" do
      meter1 =
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{
          name: "cached_lib"
        })

      meter2 =
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{
          name: "cached_lib"
        })

      assert meter1 === meter2
    end
  end
end
