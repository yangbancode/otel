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
      Otel.API.Logs.LoggerProvider.set_provider(SomeLoggerProvider)
      assert Otel.API.Logs.LoggerProvider.get_provider() == SomeLoggerProvider
    end
  end

  describe "get_logger/1,2,3" do
    test "returns noop logger when no SDK installed" do
      {module, _config} = Otel.API.Logs.LoggerProvider.get_logger("my_lib")
      assert module == Otel.API.Logs.Logger.Noop
    end

    test "returns same logger for same name" do
      logger1 = Otel.API.Logs.LoggerProvider.get_logger("my_lib")
      logger2 = Otel.API.Logs.LoggerProvider.get_logger("my_lib")
      assert logger1 == logger2
    end

    test "accepts version and schema_url" do
      logger =
        Otel.API.Logs.LoggerProvider.get_logger("my_lib", "1.0.0", "https://example.com")

      assert {Otel.API.Logs.Logger.Noop, []} == logger
    end

    test "accepts attributes" do
      logger =
        Otel.API.Logs.LoggerProvider.get_logger("my_lib", "1.0.0", nil, %{"key" => "val"})

      assert {Otel.API.Logs.Logger.Noop, []} == logger
    end

    test "returns working logger for nil name with warning" do
      {module, _config} = Otel.API.Logs.LoggerProvider.get_logger(nil)
      assert module == Otel.API.Logs.Logger.Noop
    end

    test "returns working logger for empty name with warning" do
      {module, _config} = Otel.API.Logs.LoggerProvider.get_logger("")
      assert module == Otel.API.Logs.Logger.Noop
    end

    test "caches logger in persistent_term" do
      logger1 = Otel.API.Logs.LoggerProvider.get_logger("cached_lib")
      logger2 = Otel.API.Logs.LoggerProvider.get_logger("cached_lib")
      assert logger1 === logger2
    end
  end

  describe "scope/1,2,3" do
    test "creates InstrumentationScope with name" do
      scope = Otel.API.Logs.LoggerProvider.scope("my_lib")

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "",
               schema_url: nil,
               attributes: %{}
             } == scope
    end

    test "creates InstrumentationScope with all fields" do
      scope =
        Otel.API.Logs.LoggerProvider.scope("my_lib", "1.0.0", "https://example.com", %{
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
