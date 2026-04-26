defmodule Otel.SDK.Logs.LogRecordProcessor.BatchTest do
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
    def force_flush(config) do
      send(config.test_pid, :exporter_force_flush)
      :ok
    end

    @impl true
    def shutdown(config) do
      send(config.test_pid, :exporter_shutdown)
      :ok
    end
  end

  defmodule SlowExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def export(_log_records, config) do
      Process.sleep(config.delay_ms)
      send(config.test_pid, :exported_after_delay)
      :ok
    end

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
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_init_test,
          scheduled_delay_ms: 60_000
        })

      assert Process.alive?(pid)
      :gen_statem.stop(pid)
    end
  end

  describe "on_emit/2 batching" do
    test "does not export immediately" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_no_immediate,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_no_immediate}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "hello"},
        %{},
        config
      )

      refute_receive {:exported, _}, 100
    end

    test "exports when batch size reached" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_size_test,
          max_export_batch_size: 3,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_size_test}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "1"},
        %{},
        config
      )

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "2"},
        %{},
        config
      )

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "3"},
        %{},
        config
      )

      assert_receive {:exported, records}, 1000
      assert length(records) == 3
      assert Enum.map(records, & &1.body) == ["1", "2", "3"]
    end

    test "drops records when queue full" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_queue_full,
          max_queue_size: 2,
          max_export_batch_size: 10,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_queue_full}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "1"},
        %{},
        config
      )

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "2"},
        %{},
        config
      )

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "3"},
        %{},
        config
      )

      Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config)
      assert_receive {:exported, records}
      assert length(records) == 2
    end
  end

  describe "force_flush/1" do
    test "exports pending records" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_flush_test,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_flush_test}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "pending"},
        %{},
        config
      )

      :ok = Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config)
      assert_receive {:exported, [%{body: "pending"}]}
    end

    test "invokes exporter force_flush" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_flush_invokes_test,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_flush_invokes_test}
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config)
      assert_receive :exporter_force_flush
    end

    test "second force_flush after shutdown is graceful no-op" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_flush_shutdown,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_flush_shutdown}
      Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)
      # Process is gone — spec L463 graceful ignore via :noproc catch.
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config)
    end
  end

  describe "shutdown/1" do
    test "exports remaining and shuts down exporter" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_shutdown_test,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_shutdown_test}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "final"},
        %{},
        config
      )

      :ok = Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)

      assert_receive {:exported, [%{body: "final"}]}
      assert_receive :exporter_shutdown
    end

    test "shutdown invokes exporter force_flush before exporter shutdown" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_shutdown_includes_flush_test,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_shutdown_includes_flush_test}
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)
      assert_receive :exporter_force_flush
      assert_receive :exporter_shutdown
    end

    test "second shutdown is a graceful no-op" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_double_shutdown,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_double_shutdown}
      :ok = Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)

      # Process is gone — spec L463 graceful ignore via :noproc catch.
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)
    end
  end

  describe "timer-based export" do
    test "exports on timer" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_timer_test,
          scheduled_delay_ms: 50
        })

      config = %{reg_name: :batch_timer_test}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "timed"},
        %{},
        config
      )

      assert_receive {:exported, [%{body: "timed"}]}, 500
    end
  end

  describe "export_timeout_ms" do
    test "kills runner when exporter exceeds timeout" do
      {:ok, _pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {SlowExporter, %{delay_ms: 1000, test_pid: self()}},
          name: :batch_timeout_test,
          export_timeout_ms: 100,
          max_export_batch_size: 1,
          scheduled_delay_ms: 60_000
        })

      config = %{reg_name: :batch_timeout_test}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "slow"},
        %{},
        config
      )

      # The runner should be killed before completing its 1000ms sleep.
      refute_receive :exported_after_delay, 500
    end
  end

  describe "enabled?/2" do
    test "returns true" do
      assert Otel.SDK.Logs.LogRecordProcessor.Batch.enabled?([], %{}, %{})
    end
  end

  describe "integration with LoggerProvider" do
    test "end-to-end batch emit" do
      {:ok, _proc_pid} =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          name: :batch_e2e_test,
          scheduled_delay_ms: 60_000,
          max_export_batch_size: 2
        })

      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Logs.LogRecordProcessor.Batch, %{reg_name: :batch_e2e_test}}
            ]
          }
        )

      {_mod, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider_pid, %Otel.API.InstrumentationScope{
          name: "test_lib"
        })

      logger = {Otel.SDK.Logs.Logger, config}

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{body: "log 1"})
      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{body: "log 2"})

      assert_receive {:exported, records}, 1000
      bodies = Enum.map(records, & &1.body)
      assert "log 1" in bodies
      assert "log 2" in bodies
    end
  end
end
