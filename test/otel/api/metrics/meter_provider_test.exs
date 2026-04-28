defmodule Otel.API.Metrics.MeterProviderTest do
  use ExUnit.Case, async: false

  defmodule FakeMeterProvider do
    @moduledoc false
    @behaviour Otel.API.Metrics.MeterProvider

    @impl true
    def get_meter(state, %Otel.API.InstrumentationScope{} = scope) do
      {__MODULE__, %{state: state, scope: scope}}
    end
  end

  setup do
    saved = :persistent_term.get({Otel.API.Metrics.MeterProvider, :global}, nil)
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})

    on_exit(fn ->
      if saved,
        do: :persistent_term.put({Otel.API.Metrics.MeterProvider, :global}, saved),
        else: :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    end)
  end

  describe "set_provider/1 + get_provider/0" do
    test "round-trip; nil before set, opaque tuple after" do
      assert Otel.API.Metrics.MeterProvider.get_provider() == nil

      Otel.API.Metrics.MeterProvider.set_provider({SomeProvider, :opaque_state})

      assert Otel.API.Metrics.MeterProvider.get_provider() == {SomeProvider, :opaque_state}
    end
  end

  describe "get_meter/1 — Noop fallback when no provider is set" do
    test "returns the Noop meter handle, with explicit scope or default" do
      assert {Otel.API.Metrics.Meter.Noop, []} ==
               Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{
                 name: "my_lib"
               })

      assert {Otel.API.Metrics.Meter.Noop, []} == Otel.API.Metrics.MeterProvider.get_meter()
    end

    # Spec metrics/api.md L153-L155: two Meters created with the
    # same parameters MUST be identical. Satisfied structurally.
    test "repeated calls with the same scope yield equal meter handles" do
      scope = %Otel.API.InstrumentationScope{name: "my_lib"}

      assert Otel.API.Metrics.MeterProvider.get_meter(scope) ==
               Otel.API.Metrics.MeterProvider.get_meter(scope)
    end
  end

  describe "get_meter/1 — dispatches to the registered provider" do
    setup do
      Otel.API.Metrics.MeterProvider.set_provider({FakeMeterProvider, :installed})
    end

    test "forwards scope and provider state to the registered module" do
      scope = %Otel.API.InstrumentationScope{name: "installed_lib"}

      assert {FakeMeterProvider, %{state: :installed, scope: ^scope}} =
               Otel.API.Metrics.MeterProvider.get_meter(scope)
    end

    test "different scopes produce distinct meters" do
      scope_a = %Otel.API.InstrumentationScope{name: "lib", attributes: %{"env" => "prod"}}
      scope_b = %Otel.API.InstrumentationScope{name: "lib", attributes: %{"env" => "staging"}}

      assert {_, %{scope: ^scope_a}} = Otel.API.Metrics.MeterProvider.get_meter(scope_a)
      assert {_, %{scope: ^scope_b}} = Otel.API.Metrics.MeterProvider.get_meter(scope_b)
    end
  end

  # Regression: the resolve path was caching Noop in
  # `:persistent_term` before SDK install, and the cached Noop
  # survived `set_provider/1`, silently swallowing every later
  # measurement. The cache must be re-resolved per call.
  test "an SDK installed AFTER a Noop resolve takes effect on the next resolve" do
    scope = %Otel.API.InstrumentationScope{name: "bootstrap_race"}

    assert {Otel.API.Metrics.Meter.Noop, []} ==
             Otel.API.Metrics.MeterProvider.get_meter(scope)

    Otel.API.Metrics.MeterProvider.set_provider({FakeMeterProvider, :installed})

    assert {FakeMeterProvider, %{state: :installed, scope: ^scope}} =
             Otel.API.Metrics.MeterProvider.get_meter(scope)
  end
end
