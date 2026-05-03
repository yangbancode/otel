defmodule Otel.Trace.SpanProcessorTest do
  use ExUnit.Case, async: false

  defmodule TestExporter do
    @moduledoc false

    def init(config), do: {:ok, config}

    def export(spans, _resource, %{test_pid: pid}) do
      send(pid, {:exported, length(spans), Enum.map(spans, & &1.name)})
      :ok
    end

    def shutdown(%{test_pid: pid}) do
      send(pid, :exporter_shutdown)
      :ok
    end

    def force_flush(_state), do: :ok
  end

  defmodule SlowExporter do
    @moduledoc false

    def init(config), do: {:ok, config}
    def export(_spans, _resource, _state), do: :ok

    def shutdown(_state) do
      Process.sleep(100)
      :ok
    end

    def force_flush(_state) do
      Process.sleep(100)
      :ok
    end
  end

  defmodule IgnoreExporter do
    @moduledoc false

    def init(_config), do: :ignore
    def export(_spans, _resource, _state), do: :ok
    def shutdown(_state), do: :ok
    def force_flush(_state), do: :ok
  end

  @sampled %Otel.Trace.Span{
    trace_id: 1,
    span_id: 1,
    name: "sampled",
    trace_flags: 1,
    is_recording: true
  }

  @unsampled %Otel.Trace.Span{
    trace_id: 2,
    span_id: 2,
    name: "unsampled",
    trace_flags: 0,
    is_recording: true
  }

  setup do
    Otel.TestSupport.stop_all()
    on_exit(fn -> Application.ensure_all_started(:otel) end)
    :ok
  end

  defp start_processor(exporter \\ {TestExporter, %{test_pid: self()}}) do
    Otel.TestSupport.stop_all()
    {:ok, _pid} = Otel.Trace.SpanProcessor.start_link(%{exporter: exporter})
    :ok
  end

  describe "on_end/1 — queue + sampling" do
    test "sampled span is queued (no immediate export); unsampled is dropped" do
      :ok = start_processor()

      assert :ok = Otel.Trace.SpanProcessor.on_end(@sampled)
      refute_receive {:exported, _, _}, 50

      assert :dropped = Otel.Trace.SpanProcessor.on_end(@unsampled)
    end
  end

  describe "force_flush/1" do
    test "force_flush exports immediately; no-op when queue is empty" do
      :ok = start_processor()

      for i <- 1..5 do
        Otel.Trace.SpanProcessor.on_end(%{@sampled | span_id: i, name: "span_#{i}"})
      end

      assert :ok = Otel.Trace.SpanProcessor.force_flush()
      assert_receive {:exported, 5, _names}

      :ok = start_processor()
      assert :ok = Otel.Trace.SpanProcessor.force_flush()
      refute_receive {:exported, _, _}, 50
    end
  end

  describe "supervisor-driven termination" do
    test "terminate/2 drains queue and calls exporter shutdown" do
      :ok = start_processor()
      Otel.Trace.SpanProcessor.on_end(@sampled)

      pid = Process.whereis(Otel.Trace.SpanProcessor)
      Process.unlink(pid)
      ref = Process.monitor(pid)
      Process.exit(pid, :shutdown)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      assert_receive {:exported, 1, ["sampled"]}
      assert_receive :exporter_shutdown
    end
  end

  test "exporter init/1 returning :ignore — every on_end is :dropped; force_flush still :ok" do
    :ok = start_processor({IgnoreExporter, %{}})

    Otel.Trace.SpanProcessor.on_end(@sampled)
    assert :ok = Otel.Trace.SpanProcessor.force_flush()
  end
end
