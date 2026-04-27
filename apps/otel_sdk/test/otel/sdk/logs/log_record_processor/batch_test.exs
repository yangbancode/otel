defmodule Otel.SDK.Logs.LogRecordProcessor.BatchTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

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

  defp start_batch(opts) do
    {:ok, pid} =
      Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(
        Map.merge(%{scheduled_delay_ms: 60_000}, opts)
      )

    pid
  end

  describe "start_link and init" do
    test "starts with exporter" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      assert Process.alive?(pid)
      :gen_statem.stop(pid)
    end
  end

  describe "on_emit/2 batching" do
    test "does not export immediately" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "hello"},
        %{},
        %{pid: pid}
      )

      refute_receive {:exported, _}, 100
    end

    test "exports when batch size reached" do
      pid =
        start_batch(%{
          exporter: {TestExporter, %{test_pid: self()}},
          max_export_batch_size: 3
        })

      config = %{pid: pid}

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
      pid =
        start_batch(%{
          exporter: {TestExporter, %{test_pid: self()}},
          max_queue_size: 2,
          max_export_batch_size: 10
        })

      config = %{pid: pid}

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
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "pending"},
        %{},
        config
      )

      :ok = Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config)
      assert_receive {:exported, [%{body: "pending"}]}
    end

    test "invokes exporter force_flush" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(%{pid: pid})
      assert_receive :exporter_force_flush
    end

    test "force_flush after shutdown returns {:error, :already_shutdown}" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      config = %{pid: pid}
      Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)

      assert {:error, :already_shutdown} ==
               Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config)
    end
  end

  describe "shutdown/1" do
    test "exports remaining and shuts down exporter" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      config = %{pid: pid}

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
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(%{pid: pid})
      assert_receive :exporter_force_flush
      assert_receive :exporter_shutdown
    end

    test "second shutdown returns {:error, :already_shutdown}" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      config = %{pid: pid}
      :ok = Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)

      assert {:error, :already_shutdown} ==
               Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)
    end
  end

  describe "timer-based export" do
    test "exports on timer" do
      pid =
        Otel.SDK.Logs.LogRecordProcessor.Batch.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}},
          scheduled_delay_ms: 50
        })
        |> elem(1)

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "timed"},
        %{},
        %{pid: pid}
      )

      assert_receive {:exported, [%{body: "timed"}]}, 500
    end
  end

  describe "export_timeout_ms" do
    test "kills runner when exporter exceeds timeout" do
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 1000, test_pid: self()}},
          export_timeout_ms: 100,
          max_export_batch_size: 1
        })

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "slow"},
        %{},
        %{pid: pid}
      )

      refute_receive :exported_after_delay, 500
    end
  end

  describe "caller-supplied timeout" do
    test "force_flush/2 returns {:error, :timeout} when the budget is exceeded" do
      pid = start_batch(%{exporter: {SlowExporter, %{delay_ms: 1000, test_pid: self()}}})
      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "slow"},
        %{},
        config
      )

      assert {:error, :timeout} ==
               Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config, 50)
    end

    test "shutdown/2 returns {:error, :timeout} when the budget is exceeded" do
      pid = start_batch(%{exporter: {SlowExporter, %{delay_ms: 1000, test_pid: self()}}})
      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "slow"},
        %{},
        config
      )

      assert {:error, :timeout} ==
               Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config, 50)
    end

    test "force_flush/2 during in-flight export waits for the runner if the deadline allows" do
      # Runner takes 50ms, caller's deadline is 5_000ms — the runner
      # is allowed to finish, then the pending_call drains the queue
      # and calls the exporter's force_flush. Spec L487-L491 says
      # MAY abort, not MUST abort, so we should not abort if the
      # deadline gives us time.
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 50, test_pid: self()}},
          max_export_batch_size: 1
        })

      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "queued"},
        %{},
        config
      )

      # Give the gen_statem a moment to enter :exporting.
      Process.sleep(10)

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config, 5_000)

      # Runner did finish (export delivered the post-sleep send).
      assert_receive :exported_after_delay, 500
    end

    test "shutdown/2 during in-flight export waits for the runner if the deadline allows" do
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 50, test_pid: self()}},
          max_export_batch_size: 1
        })

      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "queued"},
        %{},
        config
      )

      Process.sleep(10)

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config, 5_000)
      assert_receive :exported_after_delay, 500
    end

    test "concurrent force_flush/2 calls are postponed and each gets its result" do
      # First call enters :exporting and is saved as pending_call.
      # Second call lands while pending_call is set, so it is postponed
      # and replayed in :idle after the first completes.
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 100, test_pid: self()}},
          max_export_batch_size: 1
        })

      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "queued"},
        %{},
        config
      )

      Process.sleep(10)

      task1 =
        Task.async(fn ->
          Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config, 5_000)
        end)

      # Slight stagger so task1 reaches the gen_statem first.
      Process.sleep(20)

      task2 =
        Task.async(fn ->
          Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config, 5_000)
        end)

      assert :ok == Task.await(task1, 6_000)
      assert :ok == Task.await(task2, 6_000)
    end

    test "shutdown/2 during in-flight export aborts the runner instead of waiting" do
      # Shutdown counterpart of the force_flush postpone-race
      # regression test below. Exercises the :pending_deadline
      # → reply_pending(:shutdown, ...) path which exits the
      # gen_statem cleanly via {:stop_and_reply, :normal, ...}.
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 5_000, test_pid: self()}},
          max_export_batch_size: 1,
          export_timeout_ms: 60_000
        })

      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "slow"},
        %{},
        config
      )

      Process.sleep(20)

      started_ms = System.monotonic_time(:millisecond)
      result = Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config, 100)
      elapsed_ms = System.monotonic_time(:millisecond) - started_ms

      assert result == {:error, :timeout}
      assert elapsed_ms < 1_000

      refute_receive :exported_after_delay, 500
    end

    test "force_flush/2 with timeout=0 hits the immediate-deadline path in :exporting" do
      # Caller's deadline is already gone by the time the
      # gen_statem reads the `{:force_flush, deadline}` message.
      # Exporting handler takes the `:exceeded` branch directly
      # (no :pending_deadline timer involved) — abort_runner +
      # reply_pending(:force_flush, ...).
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 5_000, test_pid: self()}},
          max_export_batch_size: 1,
          export_timeout_ms: 60_000
        })

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "slow"},
        %{},
        %{pid: pid}
      )

      Process.sleep(20)

      assert {:error, :timeout} ==
               Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(%{pid: pid}, 0)

      refute_receive :exported_after_delay, 500
    end

    test "force_flush/2 during in-flight export aborts the runner instead of waiting" do
      # Reproduces the spec L487-L491 MUST violation that PR #297 left
      # behind: if the gen_statem is in :exporting and the caller's
      # deadline is shorter than the runner's remaining time, the
      # runner used to be allowed to finish and drain to completion
      # while the caller was already gone. Now the pending_call
      # mechanism aborts the runner at the deadline and replies
      # :timeout to the caller.
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 5_000, test_pid: self()}},
          # 1 record fills the batch, immediately triggers :exporting
          max_export_batch_size: 1,
          # generous so the runner alone won't kill itself before our deadline
          export_timeout_ms: 60_000
        })

      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "slow"},
        %{},
        config
      )

      # Give the gen_statem a moment to enter :exporting and start
      # the runner before the force_flush call arrives.
      Process.sleep(20)

      started_ms = System.monotonic_time(:millisecond)
      result = Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(config, 100)
      elapsed_ms = System.monotonic_time(:millisecond) - started_ms

      assert result == {:error, :timeout}
      # If we waited for the 5_000ms runner this would be near 5_000.
      assert elapsed_ms < 1_000

      # The runner was aborted, so its delayed `send` never fires.
      refute_receive :exported_after_delay, 500
    end
  end

  describe "enabled?/4" do
    test "returns true" do
      assert Otel.SDK.Logs.LogRecordProcessor.Batch.enabled?(%{}, %{}, [], %{})
    end
  end

  describe ":exporting state — record enqueued during in-flight export" do
    test "cast during in-flight export enqueues and is exported in the next batch" do
      pid =
        start_batch(%{
          exporter: {SlowExporter, %{delay_ms: 80, test_pid: self()}},
          max_export_batch_size: 1
        })

      config = %{pid: pid}

      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "first"},
        %{},
        config
      )

      # Let the gen_statem enter :exporting before the second emit.
      Process.sleep(20)

      # This cast lands in :exporting and should enqueue without blocking.
      Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
        %Otel.SDK.Logs.LogRecord{body: "second"},
        %{},
        config
      )

      # First runner finishes, then `next_after_export/1` starts a
      # new export for the queued "second" record.
      assert_receive :exported_after_delay, 500
      assert_receive :exported_after_delay, 500
    end
  end

  describe "drop reporting" do
    test "logs a throttled warning on the next :export_timer when records were dropped" do
      log =
        capture_log(fn ->
          pid =
            start_batch(%{
              exporter: {TestExporter, %{test_pid: self()}},
              max_queue_size: 1,
              max_export_batch_size: 100,
              # Fast tick so we don't slow the suite down
              scheduled_delay_ms: 50
            })

          config = %{pid: pid}

          # Three more emits than the queue can hold → 3 drops.
          for body <- ["1", "2", "3", "4"] do
            Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
              %Otel.SDK.Logs.LogRecord{body: body},
              %{},
              config
            )
          end

          # Wait for at least one :export_timer cycle to fire and
          # report the throttled total.
          Process.sleep(120)
          Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)
        end)

      assert log =~ "queue full, dropped 3 log record(s) since last report"
    end

    test "no warning when no records were dropped" do
      log =
        capture_log(fn ->
          pid =
            start_batch(%{
              exporter: {TestExporter, %{test_pid: self()}},
              scheduled_delay_ms: 50
            })

          Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
            %Otel.SDK.Logs.LogRecord{body: "ok"},
            %{},
            %{pid: pid}
          )

          Process.sleep(120)
          Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(%{pid: pid})
        end)

      refute log =~ "dropped"
    end

    test "terminate/3 flushes the final tally on shutdown" do
      log =
        capture_log(fn ->
          pid =
            start_batch(%{
              exporter: {TestExporter, %{test_pid: self()}},
              max_queue_size: 1,
              max_export_batch_size: 100,
              # Long tick so the periodic warning never fires; only
              # `terminate/3` reports the count.
              scheduled_delay_ms: 60_000
            })

          config = %{pid: pid}

          for body <- ["1", "2", "3"] do
            Otel.SDK.Logs.LogRecordProcessor.Batch.on_emit(
              %Otel.SDK.Logs.LogRecord{body: body},
              %{},
              config
            )
          end

          # `:gen_statem.call({:shutdown, ...})` returns when the
          # gen_statem replies, but `terminate/3` (where the drop
          # warning is emitted) runs *after* the reply. Monitor + wait
          # for `:DOWN` so `capture_log` doesn't tear down before the
          # warning lands in the logger backend.
          ref = Process.monitor(pid)
          Otel.SDK.Logs.LogRecordProcessor.Batch.shutdown(config)
          assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1_000
        end)

      assert log =~ "queue full, dropped 2 log record(s) since last report"
    end
  end

  describe "graceful handling of stray runner messages" do
    test ":idle absorbs stray :export_done from an aborted runner" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      send(pid, {:export_done, self()})
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(%{pid: pid})
      assert Process.alive?(pid)
    end

    test ":idle absorbs stray :DOWN from an aborted runner" do
      pid = start_batch(%{exporter: {TestExporter, %{test_pid: self()}}})
      send(pid, {:DOWN, make_ref(), :process, self(), :killed})
      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Batch.force_flush(%{pid: pid})
      assert Process.alive?(pid)
    end
  end

  describe "integration with LoggerProvider" do
    test "end-to-end batch emit" do
      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Logs.LogRecordProcessor.Batch,
               %{
                 exporter: {TestExporter, %{test_pid: self()}},
                 scheduled_delay_ms: 60_000,
                 max_export_batch_size: 2
               }}
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
