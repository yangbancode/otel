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

      Otel.SDK.Logs.BatchProcessor.on_emit(
        %{body: Otel.API.Common.AnyValue.string("hello")},
        config
      )

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
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: Otel.API.Common.AnyValue.string("1")}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: Otel.API.Common.AnyValue.string("2")}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: Otel.API.Common.AnyValue.string("3")}, config)

      assert_receive {:exported, records}, 1000
      assert length(records) == 3

      assert Enum.map(records, & &1.body) == [
               Otel.API.Common.AnyValue.string("1"),
               Otel.API.Common.AnyValue.string("2"),
               Otel.API.Common.AnyValue.string("3")
             ]
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
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: Otel.API.Common.AnyValue.string("1")}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: Otel.API.Common.AnyValue.string("2")}, config)
      Otel.SDK.Logs.BatchProcessor.on_emit(%{body: Otel.API.Common.AnyValue.string("3")}, config)

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

      Otel.SDK.Logs.BatchProcessor.on_emit(
        %{body: Otel.API.Common.AnyValue.string("pending")},
        config
      )

      :ok = Otel.SDK.Logs.BatchProcessor.force_flush(config)
      pending_body = Otel.API.Common.AnyValue.string("pending")
      assert_receive {:exported, [%{body: ^pending_body}]}
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

      Otel.SDK.Logs.BatchProcessor.on_emit(
        %{body: Otel.API.Common.AnyValue.string("final")},
        config
      )

      :ok = Otel.SDK.Logs.BatchProcessor.shutdown(config)

      final_body = Otel.API.Common.AnyValue.string("final")
      assert_receive {:exported, [%{body: ^final_body}]}
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

      Otel.SDK.Logs.BatchProcessor.on_emit(
        %{body: Otel.API.Common.AnyValue.string("timed")},
        config
      )

      timed_body = Otel.API.Common.AnyValue.string("timed")
      assert_receive {:exported, [%{body: ^timed_body}]}, 500
    end
  end

  describe "enabled?/2" do
    test "returns true" do
      assert Otel.SDK.Logs.BatchProcessor.enabled?([], %{})
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

      Otel.API.Logs.Logger.emit(logger, %{body: Otel.API.Common.AnyValue.string("log 1")})
      Otel.API.Logs.Logger.emit(logger, %{body: Otel.API.Common.AnyValue.string("log 2")})

      assert_receive {:exported, records}, 1000
      bodies = Enum.map(records, & &1.body)
      assert Otel.API.Common.AnyValue.string("log 1") in bodies
      assert Otel.API.Common.AnyValue.string("log 2") in bodies

      GenServer.stop(proc_pid)
    end
  end
end
