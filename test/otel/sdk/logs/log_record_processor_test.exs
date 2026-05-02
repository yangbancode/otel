defmodule Otel.SDK.Logs.LogRecordProcessorTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule TestExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}
    @impl true
    def export(records, %{test_pid: pid}) do
      send(pid, {:exported, records})
      :ok
    end

    @impl true
    def force_flush(%{test_pid: pid}) do
      send(pid, :exporter_force_flush)
      :ok
    end

    @impl true
    def shutdown(%{test_pid: pid}) do
      send(pid, :exporter_shutdown)
      :ok
    end
  end

  defmodule SlowExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}
    @impl true
    def export(_records, config) do
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
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
    :ok
  end

  defp start_batch(opts) do
    {:ok, pid} =
      Otel.SDK.Logs.LogRecordProcessor.start_link(Map.merge(%{scheduled_delay_ms: 60_000}, opts))

    %{pid: pid}
  end

  defp emit(config, body) do
    Otel.SDK.Logs.LogRecordProcessor.on_emit(
      %Otel.SDK.Logs.LogRecord{body: body},
      %{},
      config
    )
  end

  describe "on_emit/3 — queue + batch threshold + overflow" do
    test "single emit is queued, no immediate export" do
      config = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      emit(config, "hello")
      refute_receive {:exported, _}, 100
    end

    test "auto-exports when the queue reaches max_export_batch_size" do
      config =
        start_batch(%{
          exporter: {TestExporter, %{test_pid: self()}},
          max_export_batch_size: 3
        })

      for body <- ["1", "2", "3"], do: emit(config, body)

      assert_receive {:exported, records}, 1000
      assert Enum.map(records, & &1.body) == ["1", "2", "3"]
    end

    test "drops records when max_queue_size is exceeded" do
      config =
        start_batch(%{
          exporter: {TestExporter, %{test_pid: self()}},
          max_queue_size: 2,
          max_export_batch_size: 10
        })

      for body <- ["1", "2", "3"], do: emit(config, body)

      Otel.SDK.Logs.LogRecordProcessor.force_flush(config)
      assert_receive {:exported, records}
      assert length(records) == 2
    end
  end

  test "scheduled timer triggers a periodic export" do
    config =
      start_batch(%{
        exporter: {TestExporter, %{test_pid: self()}},
        scheduled_delay_ms: 50
      })

    emit(config, "timed")
    assert_receive {:exported, [%{body: "timed"}]}, 500
  end

  test "enabled?/4 always returns true" do
    assert Otel.SDK.Logs.LogRecordProcessor.enabled?(%{}, %{}, [], %{})
  end

  describe "force_flush/1 + shutdown/1" do
    test "force_flush exports queued records and invokes exporter.force_flush" do
      config = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      emit(config, "pending")

      assert :ok = Otel.SDK.Logs.LogRecordProcessor.force_flush(config)
      assert_receive {:exported, [%{body: "pending"}]}
      assert_receive :exporter_force_flush
    end

    test "shutdown drains queue, calls exporter force_flush + shutdown in order" do
      config = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      emit(config, "final")

      assert :ok = Otel.SDK.Logs.LogRecordProcessor.shutdown(config)
      assert_receive {:exported, [%{body: "final"}]}
      assert_receive :exporter_force_flush
      assert_receive :exporter_shutdown
    end

    test "second shutdown / force_flush after first → {:error, :already_shutdown}" do
      config = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      :ok = Otel.SDK.Logs.LogRecordProcessor.shutdown(config)

      assert {:error, :already_shutdown} =
               Otel.SDK.Logs.LogRecordProcessor.shutdown(config)

      assert {:error, :already_shutdown} =
               Otel.SDK.Logs.LogRecordProcessor.force_flush(config)
    end
  end

  describe "caller-supplied timeout (spec L487-L491)" do
    test "force_flush/2 + shutdown/2 → {:error, :timeout} when budget exceeded" do
      slow_exporter = {SlowExporter, %{delay_ms: 1000, test_pid: self()}}

      flush_cfg = start_batch(%{exporter: slow_exporter})
      emit(flush_cfg, "slow")

      assert {:error, :timeout} =
               Otel.SDK.Logs.LogRecordProcessor.force_flush(flush_cfg, 50)

      shut_cfg = start_batch(%{exporter: slow_exporter})
      emit(shut_cfg, "slow")

      assert {:error, :timeout} =
               Otel.SDK.Logs.LogRecordProcessor.shutdown(shut_cfg, 50)
    end

    test "force_flush/2 + shutdown/2 wait for an in-flight runner when the deadline allows" do
      runner_finishes_within_deadline = %{
        exporter: {SlowExporter, %{delay_ms: 50, test_pid: self()}},
        max_export_batch_size: 1
      }

      flush_cfg = start_batch(runner_finishes_within_deadline)
      emit(flush_cfg, "queued")
      Process.sleep(10)

      assert :ok = Otel.SDK.Logs.LogRecordProcessor.force_flush(flush_cfg, 5_000)
      assert_receive :exported_after_delay, 500

      shut_cfg = start_batch(runner_finishes_within_deadline)
      emit(shut_cfg, "queued")
      Process.sleep(10)

      assert :ok = Otel.SDK.Logs.LogRecordProcessor.shutdown(shut_cfg, 5_000)
      assert_receive :exported_after_delay, 500
    end

    # PR #297 left a hole here: caller's deadline was ignored if a
    # long-running export was already in flight. Both force_flush
    # and shutdown must abort the runner when the deadline can't
    # accommodate it.
    test "force_flush/2 + shutdown/2 abort an in-flight runner whose remaining time exceeds the deadline" do
      cfg_for_pid = fn pid -> %{pid: pid} end

      slow_5s = %{
        exporter: {SlowExporter, %{delay_ms: 5_000, test_pid: self()}},
        max_export_batch_size: 1,
        export_timeout_ms: 60_000
      }

      flush_cfg = start_batch(slow_5s)
      emit(flush_cfg, "slow")
      Process.sleep(20)

      started = System.monotonic_time(:millisecond)

      assert {:error, :timeout} =
               Otel.SDK.Logs.LogRecordProcessor.force_flush(flush_cfg, 100)

      assert System.monotonic_time(:millisecond) - started < 1_000
      refute_receive :exported_after_delay, 500

      shut_cfg = start_batch(slow_5s)
      emit(shut_cfg, "slow")
      Process.sleep(20)

      started = System.monotonic_time(:millisecond)
      assert {:error, :timeout} = Otel.SDK.Logs.LogRecordProcessor.shutdown(shut_cfg, 100)
      assert System.monotonic_time(:millisecond) - started < 1_000
      refute_receive :exported_after_delay, 500

      _ = cfg_for_pid
    end

    test "force_flush/2 with timeout: 0 takes the immediate-deadline branch in :exporting" do
      config =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 5_000, test_pid: self()}},
          max_export_batch_size: 1,
          export_timeout_ms: 60_000
        })

      emit(config, "slow")
      Process.sleep(20)

      assert {:error, :timeout} =
               Otel.SDK.Logs.LogRecordProcessor.force_flush(config, 0)

      refute_receive :exported_after_delay, 500
    end

    test "concurrent force_flush/2 calls are postponed and each receives its result" do
      config =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 100, test_pid: self()}},
          max_export_batch_size: 1
        })

      emit(config, "queued")
      Process.sleep(10)

      task1 =
        Task.async(fn -> Otel.SDK.Logs.LogRecordProcessor.force_flush(config, 5_000) end)

      Process.sleep(20)

      task2 =
        Task.async(fn -> Otel.SDK.Logs.LogRecordProcessor.force_flush(config, 5_000) end)

      assert :ok = Task.await(task1, 6_000)
      assert :ok = Task.await(task2, 6_000)
    end
  end

  test "export_timeout_ms kills runner whose export exceeds the budget" do
    config =
      start_batch(%{
        exporter: {SlowExporter, %{delay_ms: 1000, test_pid: self()}},
        export_timeout_ms: 100,
        max_export_batch_size: 1
      })

    emit(config, "slow")
    refute_receive :exported_after_delay, 500
  end

  test ":exporting — record cast during in-flight export queues for the next batch" do
    config =
      start_batch(%{
        exporter: {SlowExporter, %{delay_ms: 80, test_pid: self()}},
        max_export_batch_size: 1
      })

    emit(config, "first")
    Process.sleep(20)
    emit(config, "second")

    assert_receive :exported_after_delay, 500
    assert_receive :exported_after_delay, 500
  end

  describe "drop reporting" do
    test "throttled warning fires from a periodic :export_timer + final tally on terminate" do
      log =
        capture_log(fn ->
          config =
            start_batch(%{
              exporter: {TestExporter, %{test_pid: self()}},
              max_queue_size: 1,
              max_export_batch_size: 100,
              scheduled_delay_ms: 50
            })

          for body <- ["1", "2", "3", "4"], do: emit(config, body)
          Process.sleep(120)
          Otel.SDK.Logs.LogRecordProcessor.shutdown(config)
        end)

      assert log =~ "queue full — dropped"
    end

    test "no warning when nothing was dropped" do
      log =
        capture_log(fn ->
          config =
            start_batch(%{
              exporter: {TestExporter, %{test_pid: self()}},
              scheduled_delay_ms: 50
            })

          emit(config, "ok")
          Process.sleep(120)
          Otel.SDK.Logs.LogRecordProcessor.shutdown(config)
        end)

      refute log =~ "dropped"
    end
  end

  describe "graceful handling of stray runner messages" do
    test ":idle absorbs stray :export_done and :DOWN from an aborted runner" do
      config = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      send(config.pid, {:export_done, self()})
      send(config.pid, {:DOWN, make_ref(), :process, self(), :killed})

      assert :ok = Otel.SDK.Logs.LogRecordProcessor.force_flush(config)
      assert Process.alive?(config.pid)
    end
  end

  test "end-to-end emit through LoggerProvider exports via the Batch processor" do
    Application.stop(:otel)

    Application.put_env(:otel, :logs,
      processors: [
        {Otel.SDK.Logs.LogRecordProcessor,
         %{
           exporter: {TestExporter, %{test_pid: self()}},
           scheduled_delay_ms: 60_000,
           max_export_batch_size: 2
         }}
      ]
    )

    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.delete_env(:otel, :logs)
    end)

    {_mod, config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(
        Otel.SDK.Logs.LoggerProvider,
        %Otel.API.InstrumentationScope{name: "test_lib"}
      )

    logger = {Otel.SDK.Logs.Logger, config}

    Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{body: "log 1"})
    Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{body: "log 2"})

    assert_receive {:exported, records}, 1000
    bodies = Enum.map(records, & &1.body)
    assert "log 1" in bodies
    assert "log 2" in bodies
  end
end
