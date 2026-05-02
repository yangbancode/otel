defmodule Otel.SDK.Trace.SpanProcessorTest do
  use ExUnit.Case, async: false

  defmodule TestExporter do
    @moduledoc false
    @behaviour Otel.SDK.Trace.SpanExporter

    @impl true
    def init(config), do: {:ok, config}
    @impl true
    def export(spans, _resource, %{test_pid: pid}) do
      send(pid, {:exported, length(spans), Enum.map(spans, & &1.name)})
      :ok
    end

    @impl true
    def shutdown(%{test_pid: pid}) do
      send(pid, :exporter_shutdown)
      :ok
    end

    @impl true
    def force_flush(_state), do: :ok
  end

  defmodule SlowExporter do
    @moduledoc false
    @behaviour Otel.SDK.Trace.SpanExporter

    @impl true
    def init(config), do: {:ok, config}
    @impl true
    def export(_spans, _resource, _state), do: :ok
    @impl true
    def shutdown(_state) do
      Process.sleep(100)
      :ok
    end

    @impl true
    def force_flush(_state) do
      Process.sleep(100)
      :ok
    end
  end

  defmodule IgnoreExporter do
    @moduledoc false
    @behaviour Otel.SDK.Trace.SpanExporter

    @impl true
    def init(_config), do: :ignore
    @impl true
    def export(_spans, _resource, _state), do: :ok
    @impl true
    def shutdown(_state), do: :ok
    @impl true
    def force_flush(_state), do: :ok
  end

  @sampled %Otel.SDK.Trace.Span{
    trace_id: 1,
    span_id: 1,
    name: "sampled",
    trace_flags: 1,
    is_recording: true
  }

  @unsampled %Otel.SDK.Trace.Span{
    trace_id: 2,
    span_id: 2,
    name: "unsampled",
    trace_flags: 0,
    is_recording: true
  }

  defp start_processor do
    {:ok, pid} =
      Otel.SDK.Trace.SpanProcessor.start_link(%{exporter: {TestExporter, %{test_pid: self()}}})

    %{pid: pid}
  end

  test "on_start/3 returns the span unchanged" do
    config = start_processor()
    assert Otel.SDK.Trace.SpanProcessor.on_start(%{}, @sampled, config) == @sampled
  end

  describe "on_end/2 — queue + sampling" do
    test "sampled span is queued (no immediate export); unsampled is dropped" do
      config = start_processor()

      assert :ok = Otel.SDK.Trace.SpanProcessor.on_end(@sampled, config)
      refute_receive {:exported, _, _}, 50

      assert :dropped = Otel.SDK.Trace.SpanProcessor.on_end(@unsampled, config)
    end
  end

  describe "force_flush/1,2" do
    test "force_flush exports immediately; no-op when queue is empty" do
      config = start_processor()

      for i <- 1..5 do
        Otel.SDK.Trace.SpanProcessor.on_end(
          %{@sampled | span_id: i, name: "span_#{i}"},
          config
        )
      end

      assert :ok = Otel.SDK.Trace.SpanProcessor.force_flush(config)
      assert_receive {:exported, 5, _names}

      empty = start_processor()
      assert :ok = Otel.SDK.Trace.SpanProcessor.force_flush(empty)
      refute_receive {:exported, _, _}, 50
    end
  end

  describe "shutdown/1,2" do
    test "drains queue and calls exporter shutdown" do
      config = start_processor()
      Otel.SDK.Trace.SpanProcessor.on_end(@sampled, config)

      assert :ok = Otel.SDK.Trace.SpanProcessor.shutdown(config)
      assert_receive {:exported, 1, ["sampled"]}
      assert_receive :exporter_shutdown
    end

    test "shutdown / force_flush on a stopped processor → {:error, :already_shutdown}" do
      config = start_processor()
      GenServer.stop(config.pid)

      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.shutdown(config)

      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.force_flush(config)
    end

    test "shutdown / force_flush returns {:error, :timeout} on slow exporter" do
      {:ok, shut_pid} =
        Otel.SDK.Trace.SpanProcessor.start_link(%{exporter: {SlowExporter, %{}}})

      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.shutdown(%{pid: shut_pid}, 1)

      {:ok, flush_pid} =
        Otel.SDK.Trace.SpanProcessor.start_link(%{exporter: {SlowExporter, %{}}})

      Otel.SDK.Trace.SpanProcessor.on_end(@sampled, %{pid: flush_pid})

      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.force_flush(%{pid: flush_pid}, 1)
    end
  end

  test "exporter init/1 returning :ignore — every on_end is :dropped; shutdown/flush still :ok" do
    {:ok, pid} =
      Otel.SDK.Trace.SpanProcessor.start_link(%{exporter: {IgnoreExporter, %{}}})

    config = %{pid: pid}

    Otel.SDK.Trace.SpanProcessor.on_end(@sampled, config)
    assert :ok = Otel.SDK.Trace.SpanProcessor.force_flush(config)
    assert :ok = Otel.SDK.Trace.SpanProcessor.shutdown(config)
  end
end
