defmodule Otel.Logs.LogRecordProcessorTest do
  use ExUnit.Case, async: false

  defmodule TestExporter do
    @moduledoc false

    def init(config), do: {:ok, config}

    def export(records, %{test_pid: pid}) do
      send(pid, {:exported, records})
      :ok
    end

    def force_flush(%{test_pid: pid}) do
      send(pid, :exporter_force_flush)
      :ok
    end

    def shutdown(%{test_pid: pid}) do
      send(pid, :exporter_shutdown)
      :ok
    end
  end

  defmodule SlowExporter do
    @moduledoc false

    def init(config), do: {:ok, config}

    def export(_records, config) do
      Process.sleep(config.delay_ms)
      send(config.test_pid, :exported_after_delay)
      :ok
    end

    def force_flush(_config), do: :ok
    def shutdown(_config), do: :ok
  end

  setup do
    Otel.TestSupport.stop_all()
    on_exit(fn -> Application.ensure_all_started(:otel) end)
    :ok
  end

  defp start_batch(exporter) do
    Otel.TestSupport.stop_all()
    {:ok, pid} = Otel.Logs.LogRecordProcessor.start_link(%{exporter: exporter})
    # Unlink so the test process dying doesn't propagate; on_exit
    # below kills the orphan before the setup's on_exit restarts
    # `:otel` (registration would conflict otherwise — there's no
    # `shutdown/1` API anymore for graceful self-termination).
    Process.unlink(pid)
    on_exit(fn -> kill_orphan(pid) end)
    :ok
  end

  defp kill_orphan(pid) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        1_000 -> :ok
      end
    end

    :ok
  end

  defp emit(body) do
    Otel.Logs.LogRecordProcessor.on_emit(%Otel.Logs.LogRecord{body: body}, %{})
  end

  describe "on_emit/2" do
    test "single emit is queued, no immediate export" do
      :ok = start_batch({TestExporter, %{test_pid: self()}})
      emit("hello")
      refute_receive {:exported, _}, 100
    end
  end

  test "scheduled timer triggers a periodic export at the hardcoded 1000ms tick" do
    :ok = start_batch({TestExporter, %{test_pid: self()}})
    emit("timed")
    assert_receive {:exported, [%{body: "timed"}]}, 1500
  end

  describe "force_flush/1" do
    test "force_flush exports queued records and invokes exporter.force_flush" do
      :ok = start_batch({TestExporter, %{test_pid: self()}})
      emit("pending")

      assert :ok = Otel.Logs.LogRecordProcessor.force_flush()
      assert_receive {:exported, [%{body: "pending"}]}
      assert_receive :exporter_force_flush
    end
  end

  describe "supervisor-driven termination" do
    test "terminate/3 drains queue and calls exporter force_flush + shutdown in order" do
      :ok = start_batch({TestExporter, %{test_pid: self()}})
      emit("final")

      pid = Process.whereis(Otel.Logs.LogRecordProcessor)
      Process.unlink(pid)
      ref = Process.monitor(pid)
      Process.exit(pid, :shutdown)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      assert_receive {:exported, [%{body: "final"}]}
      assert_receive :exporter_force_flush
      assert_receive :exporter_shutdown
    end
  end

  describe "caller-supplied timeout (spec L487-L491)" do
    test "force_flush/1 → {:error, :timeout} when budget exceeded" do
      slow_exporter = {SlowExporter, %{delay_ms: 1000, test_pid: self()}}

      :ok = start_batch(slow_exporter)
      emit("slow")

      assert {:error, :timeout} = Otel.Logs.LogRecordProcessor.force_flush(50)
    end

    test "force_flush/1 waits for an in-flight runner when the deadline allows" do
      :ok = start_batch({SlowExporter, %{delay_ms: 50, test_pid: self()}})
      emit("queued")

      assert :ok = Otel.Logs.LogRecordProcessor.force_flush(5_000)
      assert_receive :exported_after_delay, 500
    end

    # PR #297 left a hole here: caller's deadline was ignored if a
    # long-running export was already in flight. force_flush must
    # abort the runner when the deadline can't accommodate it.
    test "force_flush/1 aborts an in-flight runner whose remaining time exceeds the deadline" do
      slow_5s = {SlowExporter, %{delay_ms: 5_000, test_pid: self()}}

      :ok = start_batch(slow_5s)
      emit("slow")

      spawn(fn ->
        try do
          Otel.Logs.LogRecordProcessor.force_flush(5_000)
        catch
          _, _ -> :ok
        end
      end)

      Process.sleep(20)

      started = System.monotonic_time(:millisecond)

      assert {:error, :timeout} = Otel.Logs.LogRecordProcessor.force_flush(100)

      assert System.monotonic_time(:millisecond) - started < 1_000
    end

    test "force_flush/1 with timeout: 0 takes the immediate-deadline branch in :exporting" do
      :ok = start_batch({SlowExporter, %{delay_ms: 5_000, test_pid: self()}})
      emit("slow")

      spawn(fn ->
        try do
          Otel.Logs.LogRecordProcessor.force_flush(5_000)
        catch
          _, _ -> :ok
        end
      end)

      Process.sleep(20)

      assert {:error, :timeout} = Otel.Logs.LogRecordProcessor.force_flush(0)
    end

    test "concurrent force_flush/1 calls are postponed and each receives its result" do
      :ok = start_batch({SlowExporter, %{delay_ms: 100, test_pid: self()}})
      emit("queued")

      task1 = Task.async(fn -> Otel.Logs.LogRecordProcessor.force_flush(5_000) end)
      Process.sleep(20)
      task2 = Task.async(fn -> Otel.Logs.LogRecordProcessor.force_flush(5_000) end)

      assert :ok = Task.await(task1, 6_000)
      assert :ok = Task.await(task2, 6_000)
    end
  end

  describe "graceful handling of stray runner messages" do
    test ":idle absorbs stray :export_done and :DOWN from an aborted runner" do
      :ok = start_batch({TestExporter, %{test_pid: self()}})
      pid = Process.whereis(Otel.Logs.LogRecordProcessor)
      send(pid, {:export_done, self()})
      send(pid, {:DOWN, make_ref(), :process, self(), :killed})

      assert :ok = Otel.Logs.LogRecordProcessor.force_flush()
      assert Process.alive?(pid)
    end
  end

  test "end-to-end emit through Otel.Logs exports via the batch processor" do
    Otel.TestSupport.restart_with(
      logs: [
        processors: [
          {Otel.Logs.LogRecordProcessor, %{exporter: {TestExporter, %{test_pid: self()}}}}
        ]
      ]
    )

    Otel.Logs.emit(%Otel.Logs.LogRecord{body: "log 1"})
    Otel.Logs.emit(%Otel.Logs.LogRecord{body: "log 2"})

    Otel.Logs.LogRecordProcessor.force_flush()

    assert_receive {:exported, records}, 1500
    bodies = Enum.map(records, & &1.body)
    assert "log 1" in bodies
    assert "log 2" in bodies
  end
end
