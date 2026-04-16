defmodule Otel.SDK.Logs.BatchProcessorTest do
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
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_init_test,
          scheduled_delay_ms: 60_000
        })

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "on_emit/2 batching" do
    test "does not export immediately" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_no_immediate,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_no_immediate}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "hello"}, config)
      refute_receive {:exported, _}, 100
    end

    test "exports when batch size reached" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_size_test,
          max_export_batch_size: 3,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_size_test}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "1"}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "2"}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "3"}, config)

      assert_receive {:exported, records}, 1000
      assert length(records) == 3
      assert Enum.map(records, & &1.body) == ["1", "2", "3"]
    end

    test "drops records when queue full" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_queue_full,
          max_queue_size: 2,
          max_export_batch_size: 10,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_queue_full}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "1"}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "2"}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "3"}, config)

      Otel.SDK.Logs.BatchProcessor.force_flush(config)
      assert_receive {:exported, records}
      assert length(records) == 2
    end
  end

  describe "force_flush/1" do
    test "exports pending records" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_flush_test,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_flush_test}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "pending"}, config)
      :ok = Otel.SDK.Logs.BatchProcessor.force_flush(config)
      assert_receive {:exported, [%{body: "pending"}]}
    end

    test "returns error after shutdown" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_flush_shutdown,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_flush_shutdown}
      Otel.SDK.Logs.BatchProcessor.shutdown(config)
      assert {:error, :shut_down} == Otel.SDK.Logs.BatchProcessor.force_flush(config)
    end
  end

  describe "shutdown/1" do
    test "exports remaining and shuts down exporter" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_shutdown_test,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_shutdown_test}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "final"}, config)
      :ok = Otel.SDK.Logs.BatchProcessor.shutdown(config)

      assert_receive {:exported, [%{body: "final"}]}
      assert_receive :exporter_shutdown
    end

    test "second shutdown returns error" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_double_shutdown,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_double_shutdown}
      :ok = Otel.SDK.Logs.BatchProcessor.shutdown(config)
      assert {:error, :already_shut_down} == Otel.SDK.Logs.BatchProcessor.shutdown(config)
    end
  end

  describe "timer-based export" do
    test "exports on timer" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_timer_test,
          scheduled_delay_ms: 50
        })

      config = %{reg_name: :batch_timer_test}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "timed"}, config)
      assert_receive {:exported, [%{body: "timed"}]}, 500
    end
  end

  describe "enabled?/2" do
    test "returns true" do
      assert Otel.SDK.Logs.BatchProcessor.enabled?([], %{})
    end
  end

  describe "env var config" do
    test "reads OTEL_BLRP_SCHEDULE_DELAY" do
      System.put_env("OTEL_BLRP_SCHEDULE_DELAY", "200")

      {:ok, pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_env_delay
        })

      System.delete_env("OTEL_BLRP_SCHEDULE_DELAY")
      GenServer.stop(pid)
    end

    test "invalid env var uses default" do
      System.put_env("OTEL_BLRP_MAX_QUEUE_SIZE", "not_a_number")

      {:ok, pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_env_invalid
        })

      System.delete_env("OTEL_BLRP_MAX_QUEUE_SIZE")
      GenServer.stop(pid)
    end

    test "empty env var uses default" do
      System.put_env("OTEL_BLRP_MAX_QUEUE_SIZE", "")

      {:ok, pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_env_empty
        })

      System.delete_env("OTEL_BLRP_MAX_QUEUE_SIZE")
      GenServer.stop(pid)
    end
  end

  describe "ignored exporter" do
    test "starts with ignored exporter and exports are no-op" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {IgnoredExporter, %{}},
          name: :batch_ignored_export,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_ignored_export}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "ignored"}, config)
      :ok = Otel.SDK.Logs.BatchProcessor.force_flush(config)
    end

    test "timer fires with ignored exporter" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {IgnoredExporter, %{}},
          name: :batch_ignored_timer,
          scheduled_delay_ms: 30
        })

      config = %{reg_name: :batch_ignored_timer}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "timed_ignored"}, config)
      Process.sleep(100)
      :ok = Otel.SDK.Logs.BatchProcessor.force_flush(config)
    end

    test "shutdown with ignored exporter" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {IgnoredExporter, %{}},
          name: :batch_ignored_shutdown,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_ignored_shutdown}
      :ok = Otel.SDK.Logs.BatchProcessor.shutdown(config)
    end
  end

  describe "emit after shutdown" do
    test "cast after shutdown is silently dropped" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_emit_after_shutdown,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_emit_after_shutdown}
      Otel.SDK.Logs.BatchProcessor.shutdown(config)
      :ok = Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "late"}, config)
      refute_receive {:exported, _}, 100
    end

    test "timer after shutdown is no-op" do
      {:ok, _pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_timer_after_shutdown,
          scheduled_delay_ms: 30
        })

      config = %{reg_name: :batch_timer_after_shutdown}
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: "before"}, config)
      Otel.SDK.Logs.BatchProcessor.shutdown(config)
      assert_receive {:exported, _}
      Process.sleep(100)
      refute_receive {:exported, _}
    end
  end

  describe "integration with LoggerProvider" do
    test "end-to-end batch emit" do
      {:ok, proc_pid} =
        Otel.SDK.Logs.BatchProcessor.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_e2e_test,
          scheduled_delay_ms: 60_000,
          max_export_batch_size: 2
        })

      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Logs.BatchProcessor, %{reg_name: :batch_e2e_test}}
            ]
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(provider_pid, "test_lib")
      logger = {Otel.SDK.Logs.Logger, config}

      Otel.API.Logs.Logger.emit(logger, %{body: "log 1"})
      Otel.API.Logs.Logger.emit(logger, %{body: "log 2"})

      assert_receive {:exported, records}, 1000
      bodies = Enum.map(records, & &1.body)
      assert "log 1" in bodies
      assert "log 2" in bodies

      GenServer.stop(proc_pid)
    end
  end
end
