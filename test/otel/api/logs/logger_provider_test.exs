defmodule Otel.API.Logs.LoggerProviderTest do
  use ExUnit.Case, async: false

  defmodule FakeLoggerProvider do
    @moduledoc false
    @behaviour Otel.API.Logs.LoggerProvider

    @impl true
    def get_logger(state, %Otel.InstrumentationScope{} = scope) do
      {__MODULE__, %{state: state, scope: scope}}
    end
  end

  setup do
    saved = :persistent_term.get({Otel.API.Logs.LoggerProvider, :global}, nil)
    :persistent_term.erase({Otel.API.Logs.LoggerProvider, :global})

    on_exit(fn ->
      if saved,
        do: :persistent_term.put({Otel.API.Logs.LoggerProvider, :global}, saved),
        else: :persistent_term.erase({Otel.API.Logs.LoggerProvider, :global})
    end)
  end

  describe "set_provider/1 + get_provider/0" do
    test "round-trip; nil before set, opaque tuple after" do
      assert Otel.API.Logs.LoggerProvider.get_provider() == nil

      Otel.API.Logs.LoggerProvider.set_provider({SomeLoggerProvider, :opaque_state})

      assert Otel.API.Logs.LoggerProvider.get_provider() ==
               {SomeLoggerProvider, :opaque_state}
    end
  end

  describe "get_logger/1 — Noop fallback when no provider is set" do
    test "returns the Noop logger handle, with explicit scope or default" do
      assert {Otel.API.Logs.Logger.Noop, []} ==
               Otel.API.Logs.LoggerProvider.get_logger(%Otel.InstrumentationScope{
                 name: "my_lib"
               })

      assert {Otel.API.Logs.Logger.Noop, []} == Otel.API.Logs.LoggerProvider.get_logger()
    end

    # Spec logs/api.md L94-L97: two Loggers created with the same
    # parameters MUST be identical. Satisfied structurally.
    test "repeated calls with the same scope yield equal logger handles" do
      scope = %Otel.InstrumentationScope{name: "my_lib"}

      assert Otel.API.Logs.LoggerProvider.get_logger(scope) ==
               Otel.API.Logs.LoggerProvider.get_logger(scope)
    end
  end

  describe "get_logger/1 — dispatches to the registered provider" do
    setup do
      Otel.API.Logs.LoggerProvider.set_provider({FakeLoggerProvider, :installed})
    end

    test "forwards scope and provider state to the registered module" do
      scope = %Otel.InstrumentationScope{name: "installed_lib"}

      assert {FakeLoggerProvider, %{state: :installed, scope: ^scope}} =
               Otel.API.Logs.LoggerProvider.get_logger(scope)
    end

    test "different scopes produce distinct loggers" do
      scope_a = %Otel.InstrumentationScope{name: "my_lib", version: "1.0.0"}
      scope_b = %Otel.InstrumentationScope{name: "my_lib", version: "2.0.0"}

      assert {_, %{scope: ^scope_a}} = Otel.API.Logs.LoggerProvider.get_logger(scope_a)
      assert {_, %{scope: ^scope_b}} = Otel.API.Logs.LoggerProvider.get_logger(scope_b)
    end
  end

  # Regression: the resolve path was caching Noop in
  # `:persistent_term` before SDK install, and the cached Noop
  # survived `set_provider/1`, silently swallowing every later log.
  test "an SDK installed AFTER a Noop resolve takes effect on the next resolve" do
    scope = %Otel.InstrumentationScope{name: "bootstrap_race"}

    assert {Otel.API.Logs.Logger.Noop, []} ==
             Otel.API.Logs.LoggerProvider.get_logger(scope)

    Otel.API.Logs.LoggerProvider.set_provider({FakeLoggerProvider, :installed})

    assert {FakeLoggerProvider, %{state: :installed, scope: ^scope}} =
             Otel.API.Logs.LoggerProvider.get_logger(scope)
  end
end
