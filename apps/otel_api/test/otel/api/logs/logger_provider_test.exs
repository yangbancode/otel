defmodule Otel.API.Logs.LoggerProviderTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Logs.LoggerProvider, :global})
    :ok
  end

  describe "get_provider/0 and set_provider/1" do
    test "returns nil when no provider is set" do
      assert Otel.API.Logs.LoggerProvider.get_provider() == nil
    end

    test "returns the set provider" do
      Otel.API.Logs.LoggerProvider.set_provider({SomeLoggerProvider, :opaque_state})
      assert Otel.API.Logs.LoggerProvider.get_provider() == {SomeLoggerProvider, :opaque_state}
    end
  end

  describe "get_logger/1 dispatch via registered provider" do
    defmodule FakeLoggerProvider do
      @moduledoc false
      @behaviour Otel.API.Logs.LoggerProvider

      @impl true
      def get_logger(state, %Otel.API.InstrumentationScope{} = scope) do
        {__MODULE__, %{state: state, scope: scope}}
      end
    end

    test "delegates to the registered provider" do
      Otel.API.Logs.LoggerProvider.set_provider({FakeLoggerProvider, :installed})

      scope = %Otel.API.InstrumentationScope{name: "installed_lib"}

      {module, %{state: :installed, scope: ^scope}} =
        Otel.API.Logs.LoggerProvider.get_logger(scope)

      assert module == FakeLoggerProvider
    end

    test "different scopes produce distinct loggers" do
      Otel.API.Logs.LoggerProvider.set_provider({FakeLoggerProvider, :installed})

      scope1 = %Otel.API.InstrumentationScope{name: "my_lib", version: "1.0.0"}
      scope2 = %Otel.API.InstrumentationScope{name: "my_lib", version: "2.0.0"}

      assert {_, %{scope: ^scope1}} = Otel.API.Logs.LoggerProvider.get_logger(scope1)
      assert {_, %{scope: ^scope2}} = Otel.API.Logs.LoggerProvider.get_logger(scope2)
    end

    # Regression test for the bootstrap race where a pre-SDK
    # `get_logger/1` would cache Noop in `:persistent_term`, and
    # that cached Noop would survive SDK installation — silently
    # dropping every subsequent log even though a real provider
    # was registered.
    test "later-installed provider takes effect immediately (no stale Noop)" do
      scope = %Otel.API.InstrumentationScope{name: "bootstrap_race"}

      # Step 1: Resolve BEFORE any provider — should be Noop.
      assert {Otel.API.Logs.Logger.Noop, []} ==
               Otel.API.Logs.LoggerProvider.get_logger(scope)

      # Step 2: Install provider AFTER the first resolve.
      Otel.API.Logs.LoggerProvider.set_provider({FakeLoggerProvider, :installed})

      # Step 3: Second resolve MUST hit the new provider, not a
      # stale Noop from step 1's resolution.
      {module, %{state: :installed, scope: ^scope}} =
        Otel.API.Logs.LoggerProvider.get_logger(scope)

      assert module == FakeLoggerProvider
    end
  end

  describe "get_logger/0,1" do
    test "returns noop logger when no SDK installed" do
      {module, _config} =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert module == Otel.API.Logs.Logger.Noop
    end

    test "returns noop logger with default empty scope when called with no args" do
      {module, _config} = Otel.API.Logs.LoggerProvider.get_logger()
      assert module == Otel.API.Logs.Logger.Noop
    end

    # Spec `logs/api.md` L94-L97: "two Loggers created with the
    # same parameters MUST be identical". Satisfied via structural
    # equality (not reference identity) since the Noop case always
    # returns `{Noop, []}`.
    test "returns structurally equal loggers for repeated equal scopes" do
      logger1 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{name: "my_lib"})

      logger2 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert logger1 == logger2
    end
  end
end
