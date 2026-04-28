defmodule Otel.SDK.Trace.SpanProcessor.BatchTest do
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

  defp start_processor(overrides \\ []) do
    config =
      Map.merge(
        %{
          exporter: {TestExporter, %{test_pid: self()}},
          scheduled_delay_ms: 100_000,
          max_queue_size: 2048,
          max_export_batch_size: 512,
          export_timeout_ms: 30_000
        },
        Map.new(overrides)
      )

    {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(config)
    %{pid: pid}
  end

  defp emit_n(config, n) do
    for i <- 1..n do
      Otel.SDK.Trace.SpanProcessor.Batch.on_end(
        %{@sampled | span_id: i, name: "span_#{i}"},
        config
      )
    end
  end

  test "on_start/3 returns the span unchanged" do
    config = start_processor()
    assert Otel.SDK.Trace.SpanProcessor.Batch.on_start(%{}, @sampled, config) == @sampled
  end

  describe "on_end/2 — queue + sampling + overflow" do
    test "sampled span is queued (no immediate export); unsampled is dropped" do
      config = start_processor()

      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled, config)
      refute_receive {:exported, _, _}, 50

      assert :dropped = Otel.SDK.Trace.SpanProcessor.Batch.on_end(@unsampled, config)
    end

    test "auto-exports when the queue length reaches max_export_batch_size" do
      config = start_processor(max_export_batch_size: 3)
      emit_n(config, 3)

      assert_receive {:exported, 3, _names}, 1000
    end

    test "drops spans when max_queue_size is reached (force_flush exports at most queue cap)" do
      config = start_processor(max_queue_size: 2, max_export_batch_size: 100)
      emit_n(config, 5)

      Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
      assert_receive {:exported, count, _names}, 1000
      assert count <= 2
    end
  end

  describe "scheduled timer + force_flush" do
    test "scheduled_delay_ms triggers a periodic export of queued spans" do
      config = start_processor(scheduled_delay_ms: 50)
      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled, config)

      assert_receive {:exported, 1, ["sampled"]}, 500
    end

    test "force_flush exports immediately; no-op when queue is empty" do
      config = start_processor()
      emit_n(config, 5)

      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
      assert_receive {:exported, 5, _names}

      empty = start_processor()
      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.force_flush(empty)
      refute_receive {:exported, _, _}, 50
    end
  end

  describe "shutdown/1,2" do
    test "drains queue and calls exporter shutdown" do
      config = start_processor()
      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled, config)

      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.shutdown(config)
      assert_receive {:exported, 1, ["sampled"]}
      assert_receive :exporter_shutdown
    end

    test "shutdown / force_flush on a stopped processor → {:error, :already_shutdown}" do
      config = start_processor()
      GenServer.stop(config.pid)

      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.Batch.shutdown(config)

      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
    end

    test "shutdown / force_flush returns {:error, :timeout} on slow exporter" do
      slow_config = %{
        exporter: {SlowExporter, %{}},
        scheduled_delay_ms: 100_000,
        max_queue_size: 2048,
        max_export_batch_size: 512,
        export_timeout_ms: 30_000
      }

      {:ok, shut_pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(slow_config)

      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.Batch.shutdown(%{pid: shut_pid}, 1)

      {:ok, flush_pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(slow_config)
      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled, %{pid: flush_pid})

      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.Batch.force_flush(%{pid: flush_pid}, 1)
    end
  end

  # Spec trace/sdk.md L1113 — export_timeout_ms is the drain
  # deadline computed once at do_export entry; the per-batch guard
  # check refuses to start a new batch after the deadline.
  describe "export_timeout_ms enforcement" do
    test "0 prevents any drain — spans stay queued through force_flush" do
      config = start_processor(export_timeout_ms: 0, max_export_batch_size: 1)

      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled, config)
      Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)

      refute_receive {:exported, _, _}, 100
    end

    test "default (30s) leaves enough slack for a normal drain" do
      config = start_processor()
      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled, config)
      Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)

      assert_receive {:exported, 1, ["sampled"]}
    end
  end

  test "exporter init/1 returning :ignore — every on_end is :dropped; shutdown/flush still :ok" do
    {:ok, pid} =
      Otel.SDK.Trace.SpanProcessor.Batch.start_link(%{
        exporter: {IgnoreExporter, %{}},
        scheduled_delay_ms: 100_000
      })

    config = %{pid: pid}

    Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled, config)
    assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
    assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.shutdown(config)
  end
end
