defmodule Otel.SDK.Logs.LogRecordProcessor.SimpleTest do
  use ExUnit.Case

  defmodule TestExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def export(log_records, config) do
      send(config.test_pid, {:exported, log_records})
      :ok
    end

    @impl true
    def force_flush(_config), do: :ok

    @impl true
    def shutdown(config) do
      send(config.test_pid, :exporter_shutdown)
      :ok
    end
  end

  defmodule IgnoredExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(_config), do: :ignore

    @impl true
    def export(_log_records, _config), do: :ok

    @impl true
    def force_flush(_config), do: :ok

    @impl true
    def shutdown(_config), do: :ok
  end

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  describe "start_link and init" do
    test "starts with exporter" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :simple_init_test
        })

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with ignored exporter" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {IgnoredExporter, %{}},
          name: :simple_ignore_test
        })

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "on_emit/2" do
    test "exports log record immediately" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :simple_emit_test
        })

      config = %{reg_name: :simple_emit_test}
      log_record = %{body: "hello", severity_number: 9}

      Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(log_record, config)
      assert_receive {:exported, [^log_record]}
    end

    test "no-op when exporter is ignored" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {IgnoredExporter, %{}},
          name: :simple_noop_test
        })

      config = %{reg_name: :simple_noop_test}
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(%{body: "test"}, config)
    end
  end

  describe "enabled?/2" do
    test "returns true" do
      assert Otel.SDK.Logs.LogRecordProcessor.Simple.enabled?([], %{})
    end
  end

  describe "shutdown/1" do
    test "shuts down exporter" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :simple_shutdown_test
        })

      config = %{reg_name: :simple_shutdown_test}
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(config)
      assert_receive :exporter_shutdown
    end

    test "second shutdown returns error" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :simple_double_shutdown
        })

      config = %{reg_name: :simple_double_shutdown}
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(config)

      assert {:error, :already_shut_down} ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(config)
    end

    test "emit after shutdown is no-op" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :simple_emit_after_shutdown
        })

      config = %{reg_name: :simple_emit_after_shutdown}
      Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(config)
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(%{body: "late"}, config)
      refute_receive {:exported, _}
    end
  end

  describe "force_flush/1" do
    test "returns :ok" do
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(%{})
    end
  end

  describe "integration with LoggerProvider" do
    test "end-to-end emit through provider" do
      {:ok, proc_pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :simple_e2e_test
        })

      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Logs.LogRecordProcessor.Simple, %{reg_name: :simple_e2e_test}}
            ]
          }
        )

      {_mod, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider_pid, %Otel.API.InstrumentationScope{
          name: "test_lib"
        })

      logger = {Otel.SDK.Logs.Logger, config}

      Otel.API.Logs.Logger.emit(
        logger,
        %Otel.API.Logs.LogRecord{body: "e2e test", severity_number: 9}
      )

      assert_receive {:exported, [record]}
      assert record.body == "e2e test"
      assert record.scope.name == "test_lib"

      GenServer.stop(proc_pid)
    end
  end
end
