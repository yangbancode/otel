defmodule Otel.Logs.LoggerProviderTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()
    :ok
  end

  describe "init/0 + persistent_term state" do
    test "seeds resource and log_record_limits" do
      config = Otel.Logs.LoggerProvider.config()
      assert %Otel.Resource{} = config.resource
      assert %Otel.Logs.LogRecordLimits{} = config.log_record_limits
      assert config.shut_down == false
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

  describe "shutdown/1 + force_flush/1" do
    test "first shutdown :ok; subsequent → :already_shutdown" do
      assert :ok = Otel.Logs.LoggerProvider.shutdown()
      assert {:error, :already_shutdown} = Otel.Logs.LoggerProvider.shutdown()
      assert {:error, :already_shutdown} = Otel.Logs.LoggerProvider.force_flush()
    end

    test "after shutdown, get_logger returns a degenerate Logger" do
      :ok = Otel.Logs.LoggerProvider.shutdown()

      assert %Otel.Logs.Logger{} = Otel.Logs.LoggerProvider.get_logger()
    end

    test "facades stay graceful when no provider state has been seeded" do
      Otel.TestSupport.stop_all()

      assert :ok = Otel.Logs.LoggerProvider.force_flush()
      assert :ok = Otel.Logs.LoggerProvider.shutdown()
      assert %Otel.Resource{} = Otel.Logs.LoggerProvider.resource()
      assert %{} = Otel.Logs.LoggerProvider.config()
    end
  end
end
