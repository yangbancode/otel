defmodule Otel.Logs.LoggerProviderTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()
    :ok
  end

  describe "init/0 + persistent_term state" do
    test "seeds resource only" do
      config = Otel.Logs.LoggerProvider.config()
      assert %Otel.Resource{} = config.resource
      refute Map.has_key?(config, :log_record_limits)
    end

    test "resource/0 returns the seeded resource" do
      assert %Otel.Resource{} = Otel.Logs.LoggerProvider.resource()
    end
  end

  describe "get_logger/0" do
    test "returns %Logger{} struct carrying the hardcoded SDK scope, resource, and limits" do
      %Otel.Logs.Logger{config: config} = Otel.Logs.LoggerProvider.get_logger()

      assert config.scope.name == "otel"
      assert %Otel.Resource{} = config.resource
      assert %Otel.Logs.LogRecordLimits{} = config.log_record_limits
    end
  end

  describe "introspection without provider state" do
    test "resource/0 falls back to Otel.Resource.default/0" do
      Otel.TestSupport.stop_all()

      assert %Otel.Resource{} = Otel.Logs.LoggerProvider.resource()
      assert %{} = Otel.Logs.LoggerProvider.config()
    end
  end
end
