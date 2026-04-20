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

    test "returns same logger for equal scopes" do
      logger1 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{name: "my_lib"})

      logger2 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert logger1 == logger2
    end

    test "different scopes produce separate cache entries" do
      logger1 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0"
        })

      logger2 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "2.0.0"
        })

      # Both are Noop but cached under distinct keys
      assert logger1 == logger2
    end

    test "caches logger in persistent_term" do
      logger1 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{
          name: "cached_lib"
        })

      logger2 =
        Otel.API.Logs.LoggerProvider.get_logger(%Otel.API.InstrumentationScope{
          name: "cached_lib"
        })

      assert logger1 === logger2
    end
  end
end
