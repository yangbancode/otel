defmodule Otel.SDK.Trace.SpanProcessor.BatchTest.TestExporter do
  @behaviour Otel.SDK.Trace.SpanExporter

  @spec init(config :: term()) :: {:ok, Otel.SDK.Trace.SpanExporter.state()} | :ignore
  @impl true
  def init(config), do: {:ok, config}

  @spec export(
          spans :: [Otel.SDK.Trace.Span.t()],
          resource :: map(),
          state :: Otel.SDK.Trace.SpanExporter.state()
        ) :: :ok | :error
  @impl true
  def export(spans, _resource, %{test_pid: pid} = state) do
    case Map.get(state, :sleep_ms) do
      nil -> :ok
      ms -> Process.sleep(ms)
    end

    send(pid, {:exported, length(spans), Enum.map(spans, & &1.name)})
    :ok
  end

  @spec shutdown(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def shutdown(%{test_pid: pid}) do
    send(pid, :exporter_shutdown)
    :ok
  end

  @spec force_flush(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def force_flush(_state), do: :ok
end

defmodule Otel.SDK.Trace.SpanProcessor.BatchTest.SlowShutdownExporter do
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

defmodule Otel.SDK.Trace.SpanProcessor.BatchTest do
  use ExUnit.Case

  @sampled_span %Otel.SDK.Trace.Span{
    trace_id: 1,
    span_id: 1,
    name: "sampled",
    trace_flags: 1,
    is_recording: true
  }

  @unsampled_span %Otel.SDK.Trace.Span{
    trace_id: 2,
    span_id: 2,
    name: "unsampled",
    trace_flags: 0,
    is_recording: true
  }

  @spec start_processor(keyword()) :: map()
  defp start_processor(overrides \\ []) do
    config = %{
      exporter: {Otel.SDK.Trace.SpanProcessor.BatchTest.TestExporter, %{test_pid: self()}},
      scheduled_delay_ms: Keyword.get(overrides, :scheduled_delay_ms, 100_000),
      max_queue_size: Keyword.get(overrides, :max_queue_size, 2048),
      max_export_batch_size: Keyword.get(overrides, :max_export_batch_size, 512),
      export_timeout_ms: Keyword.get(overrides, :export_timeout_ms, 30_000)
    }

    {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(config)
    %{pid: pid}
  end

  describe "on_start/3" do
    test "returns span unchanged" do
      config = start_processor()
      span = Otel.SDK.Trace.SpanProcessor.Batch.on_start(%{}, @sampled_span, config)
      assert span == @sampled_span
    end
  end

  describe "on_end/2" do
    test "queues sampled spans" do
      config = start_processor()
      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled_span, config)
      refute_receive {:exported, _, _}, 50
    end

    test "drops unsampled spans" do
      config = start_processor()
      assert :dropped = Otel.SDK.Trace.SpanProcessor.Batch.on_end(@unsampled_span, config)
    end

    test "exports when batch size reached" do
      config = start_processor(max_export_batch_size: 3)

      for i <- 1..3 do
        span = %{@sampled_span | span_id: i, name: "span_#{i}"}
        Otel.SDK.Trace.SpanProcessor.Batch.on_end(span, config)
      end

      assert_receive {:exported, 3, _names}, 1000
    end

    test "drops spans when queue is full" do
      config = start_processor(max_queue_size: 2, max_export_batch_size: 100)

      for i <- 1..5 do
        span = %{@sampled_span | span_id: i, name: "span_#{i}"}
        Otel.SDK.Trace.SpanProcessor.Batch.on_end(span, config)
      end

      # Force flush to see what was queued
      Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
      assert_receive {:exported, count, _names}, 1000
      assert count <= 2
    end
  end

  describe "timer export" do
    test "exports on scheduled delay" do
      config = start_processor(scheduled_delay_ms: 50)

      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled_span, config)

      assert_receive {:exported, 1, ["sampled"]}, 500
    end
  end

  describe "force_flush/1" do
    test "exports all queued spans immediately" do
      config = start_processor()

      for i <- 1..5 do
        span = %{@sampled_span | span_id: i, name: "span_#{i}"}
        Otel.SDK.Trace.SpanProcessor.Batch.on_end(span, config)
      end

      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
      assert_receive {:exported, 5, _names}
    end

    test "no-op when queue is empty" do
      config = start_processor()
      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
      refute_receive {:exported, _, _}, 50
    end
  end

  describe "shutdown/1" do
    test "exports remaining spans and shuts down exporter" do
      config = start_processor()

      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled_span, config)
      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.shutdown(config)

      assert_receive {:exported, 1, ["sampled"]}
      assert_receive :exporter_shutdown
    end

    test "shutdown on stopped processor returns {:error, :already_shutdown}" do
      config = start_processor()
      GenServer.stop(config.pid)

      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.Batch.shutdown(config)
    end

    test "force_flush on stopped processor returns {:error, :already_shutdown}" do
      config = start_processor()
      GenServer.stop(config.pid)

      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)
    end

    test "shutdown returns {:error, :timeout} when GenServer.call exceeds timeout" do
      slow_config = %{
        exporter: {Otel.SDK.Trace.SpanProcessor.BatchTest.SlowShutdownExporter, %{}},
        scheduled_delay_ms: 100_000,
        max_queue_size: 2048,
        max_export_batch_size: 512,
        export_timeout_ms: 30_000
      }

      {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(slow_config)

      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.Batch.shutdown(%{pid: pid}, 1)
    end

    test "force_flush returns {:error, :timeout} when GenServer.call exceeds timeout" do
      slow_config = %{
        exporter: {Otel.SDK.Trace.SpanProcessor.BatchTest.SlowShutdownExporter, %{}},
        scheduled_delay_ms: 100_000,
        max_queue_size: 2048,
        max_export_batch_size: 512,
        export_timeout_ms: 30_000
      }

      {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(slow_config)
      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled_span, %{pid: pid})

      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.Batch.force_flush(%{pid: pid}, 1)
    end
  end

  describe "export_timeout_ms enforcement (spec trace/sdk.md L1113)" do
    # The drain deadline is applied between batches —
    # `do_export/1` computes `now + export_timeout_ms` once at
    # entry and `do_export_until/2` checks before each batch.
    # Individual `exporter.export/3` calls are synchronous and
    # not preempted (BEAM has no synchronous preemption); the
    # spec MUST about indefinite blocking at L1156 remains the
    # exporter's contract.

    test "export_timeout_ms: 0 prevents any drain — spans stay queued" do
      # With deadline = now + 0, the pre-batch check
      # `now < deadline` is false on the first iteration
      # so no batch is exported. The on_end auto-trigger
      # path runs through the same `do_export/1`, exercising
      # the deadline guard.
      config = %{
        exporter: {Otel.SDK.Trace.SpanProcessor.BatchTest.TestExporter, %{test_pid: self()}},
        scheduled_delay_ms: 100_000,
        max_queue_size: 2048,
        max_export_batch_size: 1,
        export_timeout_ms: 0
      }

      {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(config)
      processor_config = %{pid: pid}

      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled_span, processor_config)
      Otel.SDK.Trace.SpanProcessor.Batch.force_flush(processor_config)

      refute_receive {:exported, _, _}, 100
    end

    test "default deadline (30s) drains queue normally" do
      # Regression check: the deadline path doesn't break the
      # happy path. Default export_timeout_ms = 30_000 leaves
      # plenty of slack for a 1-span drain.
      config = start_processor()

      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled_span, config)
      Otel.SDK.Trace.SpanProcessor.Batch.force_flush(config)

      assert_receive {:exported, 1, ["sampled"]}
    end
  end

  describe "exporter :ignore" do
    test "drops spans and handles shutdown with nil exporter" do
      defmodule IgnoreExporter do
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

      config = %{
        exporter: {IgnoreExporter, %{}},
        scheduled_delay_ms: 100_000
      }

      {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Batch.start_link(config)
      proc_config = %{pid: pid}

      Otel.SDK.Trace.SpanProcessor.Batch.on_end(@sampled_span, proc_config)
      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.force_flush(proc_config)
      assert :ok = Otel.SDK.Trace.SpanProcessor.Batch.shutdown(proc_config)
    end
  end
end
