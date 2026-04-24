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

  describe "get_meter/1 dispatch via registered provider" do
    defmodule FakeMeterProvider do
      @moduledoc false
      @behaviour Otel.API.Metrics.MeterProvider

      @impl true
      def get_meter(state, %Otel.API.InstrumentationScope{} = scope) do
        {__MODULE__, %{state: state, scope: scope}}
      end
    end

    test "delegates to the registered provider" do
      Otel.API.Metrics.MeterProvider.set_provider({FakeMeterProvider, :installed})

      scope = %Otel.API.InstrumentationScope{name: "installed_lib"}

      {module, %{state: :installed, scope: ^scope}} =
        Otel.API.Metrics.MeterProvider.get_meter(scope)

      assert module == FakeMeterProvider
    end

    test "different scopes produce distinct meters" do
      Otel.API.Metrics.MeterProvider.set_provider({FakeMeterProvider, :installed})

      scope_a = %Otel.API.InstrumentationScope{name: "lib", attributes: %{"env" => "prod"}}
      scope_b = %Otel.API.InstrumentationScope{name: "lib", attributes: %{"env" => "staging"}}

      assert {_, %{scope: ^scope_a}} = Otel.API.Metrics.MeterProvider.get_meter(scope_a)
      assert {_, %{scope: ^scope_b}} = Otel.API.Metrics.MeterProvider.get_meter(scope_b)
    end

    # Regression test for the bootstrap race where a pre-SDK
    # `get_meter/1` would cache Noop in `:persistent_term`, and
    # that cached Noop would survive SDK installation — silently
    # dropping every subsequent measurement even though a real
    # provider was registered.
    test "later-installed provider takes effect immediately (no stale Noop)" do
      scope = %Otel.API.InstrumentationScope{name: "bootstrap_race"}

      # Step 1: Resolve BEFORE any provider — should be Noop.
      assert {Otel.API.Metrics.Meter.Noop, []} ==
               Otel.API.Metrics.MeterProvider.get_meter(scope)

      # Step 2: Install provider AFTER the first resolve.
      Otel.API.Metrics.MeterProvider.set_provider({FakeMeterProvider, :installed})

      # Step 3: Second resolve MUST hit the new provider, not a
      # stale Noop from step 1's resolution.
      {module, %{state: :installed, scope: ^scope}} =
        Otel.API.Metrics.MeterProvider.get_meter(scope)

      assert module == FakeMeterProvider
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

    # Spec `metrics/api.md` L153-L155: "two Meters created with
    # the same parameters MUST be identical". Satisfied via
    # structural equality (not reference identity) since the
    # Noop case always returns `{Noop, []}`.
    test "returns structurally equal meters for repeated equal scopes" do
      meter1 =
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "my_lib"})

      meter2 =
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert meter1 == meter2
    end
  end
end
