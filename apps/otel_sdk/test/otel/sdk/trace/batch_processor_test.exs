defmodule Otel.SDK.Trace.BatchProcessorTest.TestExporter do
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
  def export(spans, _resource, %{test_pid: pid}) do
    send(pid, {:exported, length(spans), Enum.map(spans, & &1.name)})
    :ok
  end

  @spec shutdown(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def shutdown(%{test_pid: pid}) do
    send(pid, :exporter_shutdown)
    :ok
  end
end

defmodule Otel.SDK.Trace.BatchProcessorTest do
  use ExUnit.Case

  @sampled_span %Otel.SDK.Trace.Span{
    trace_id: Otel.API.Trace.TraceId.new(<<1::128>>),
    span_id: Otel.API.Trace.SpanId.new(<<1::64>>),
    name: "sampled",
    trace_flags: 1,
    is_recording: true
  }

  @unsampled_span %Otel.SDK.Trace.Span{
    trace_id: Otel.API.Trace.TraceId.new(<<2::128>>),
    span_id: Otel.API.Trace.SpanId.new(<<2::64>>),
    name: "unsampled",
    trace_flags: 0,
    is_recording: true
  }

  @spec start_processor(keyword()) :: map()
  defp start_processor(overrides \\ []) do
    name = :"batch_#{System.unique_integer([:positive])}"

    config =
      %{
        exporter: {Otel.SDK.Trace.BatchProcessorTest.TestExporter, %{test_pid: self()}},
        name: name,
        scheduled_delay_ms: Keyword.get(overrides, :scheduled_delay_ms, 100_000),
        max_queue_size: Keyword.get(overrides, :max_queue_size, 2048),
        max_export_batch_size: Keyword.get(overrides, :max_export_batch_size, 512)
      }

    {:ok, _pid} = Otel.SDK.Trace.BatchProcessor.start_link(config)
    %{reg_name: name}
  end

  describe "on_start/3" do
    test "returns span unchanged" do
      config = start_processor()
      span = Otel.SDK.Trace.BatchProcessor.on_start(%{}, @sampled_span, config)
      assert span == @sampled_span
    end
  end

  describe "on_end/2" do
    test "queues sampled spans" do
      config = start_processor()
      assert :ok = Otel.SDK.Trace.BatchProcessor.on_end(@sampled_span, config)
      refute_receive {:exported, _, _}, 50
    end

    test "drops unsampled spans" do
      config = start_processor()
      assert :dropped = Otel.SDK.Trace.BatchProcessor.on_end(@unsampled_span, config)
    end

    test "exports when batch size reached" do
      config = start_processor(max_export_batch_size: 3)

      for i <- 1..3 do
        span = %{
          @sampled_span
          | span_id: Otel.API.Trace.SpanId.new(<<i::64>>),
            name: "span_#{i}"
        }

        Otel.SDK.Trace.BatchProcessor.on_end(span, config)
      end

      assert_receive {:exported, 3, _names}, 1000
    end

    test "drops spans when queue is full" do
      config = start_processor(max_queue_size: 2, max_export_batch_size: 100)

      for i <- 1..5 do
        span = %{
          @sampled_span
          | span_id: Otel.API.Trace.SpanId.new(<<i::64>>),
            name: "span_#{i}"
        }

        Otel.SDK.Trace.BatchProcessor.on_end(span, config)
      end

      # Force flush to see what was queued
      Otel.SDK.Trace.BatchProcessor.force_flush(config)
      assert_receive {:exported, count, _names}, 1000
      assert count <= 2
    end
  end

  describe "timer export" do
    test "exports on scheduled delay" do
      config = start_processor(scheduled_delay_ms: 50)

      Otel.SDK.Trace.BatchProcessor.on_end(@sampled_span, config)

      assert_receive {:exported, 1, ["sampled"]}, 500
    end
  end

  describe "force_flush/1" do
    test "exports all queued spans immediately" do
      config = start_processor()

      for i <- 1..5 do
        span = %{
          @sampled_span
          | span_id: Otel.API.Trace.SpanId.new(<<i::64>>),
            name: "span_#{i}"
        }

        Otel.SDK.Trace.BatchProcessor.on_end(span, config)
      end

      assert :ok = Otel.SDK.Trace.BatchProcessor.force_flush(config)
      assert_receive {:exported, 5, _names}
    end

    test "no-op when queue is empty" do
      config = start_processor()
      assert :ok = Otel.SDK.Trace.BatchProcessor.force_flush(config)
      refute_receive {:exported, _, _}, 50
    end
  end

  describe "shutdown/1" do
    test "exports remaining spans and shuts down exporter" do
      config = start_processor()

      Otel.SDK.Trace.BatchProcessor.on_end(@sampled_span, config)
      assert :ok = Otel.SDK.Trace.BatchProcessor.shutdown(config)

      assert_receive {:exported, 1, ["sampled"]}
      assert_receive :exporter_shutdown
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
      end

      name = :"batch_ignore_#{System.unique_integer([:positive])}"

      config = %{
        exporter: {IgnoreExporter, %{}},
        name: name,
        scheduled_delay_ms: 100_000
      }

      {:ok, _pid} = Otel.SDK.Trace.BatchProcessor.start_link(config)
      proc_config = %{reg_name: name}

      Otel.SDK.Trace.BatchProcessor.on_end(@sampled_span, proc_config)
      assert :ok = Otel.SDK.Trace.BatchProcessor.force_flush(proc_config)
      assert :ok = Otel.SDK.Trace.BatchProcessor.shutdown(proc_config)
    end
  end

  describe "OTEL_BSP_* environment variables" do
    setup do
      bsp_vars = [
        "OTEL_BSP_SCHEDULE_DELAY",
        "OTEL_BSP_EXPORT_TIMEOUT",
        "OTEL_BSP_MAX_QUEUE_SIZE",
        "OTEL_BSP_MAX_EXPORT_BATCH_SIZE"
      ]

      Enum.each(bsp_vars, &System.delete_env/1)
      on_exit(fn -> Enum.each(bsp_vars, &System.delete_env/1) end)
      :ok
    end

    test "reads BSP config from env vars" do
      System.put_env("OTEL_BSP_SCHEDULE_DELAY", "1000")
      System.put_env("OTEL_BSP_MAX_QUEUE_SIZE", "4096")

      {:ok, pid} =
        Otel.SDK.Trace.BatchProcessor.start_link(%{
          exporter: {Otel.SDK.Trace.BatchProcessorTest.TestExporter, %{test_pid: self()}},
          name: :bsp_env_test
        })

      state = :sys.get_state(pid)
      assert state.scheduled_delay_ms == 1000
      assert state.max_queue_size == 4096
      GenServer.stop(pid)
    end

    test "explicit config overrides env vars" do
      System.put_env("OTEL_BSP_SCHEDULE_DELAY", "1000")

      {:ok, pid} =
        Otel.SDK.Trace.BatchProcessor.start_link(%{
          exporter: {Otel.SDK.Trace.BatchProcessorTest.TestExporter, %{test_pid: self()}},
          scheduled_delay_ms: 2000,
          name: :bsp_override_test
        })

      state = :sys.get_state(pid)
      assert state.scheduled_delay_ms == 2000
      GenServer.stop(pid)
    end

    test "empty env var uses default" do
      System.put_env("OTEL_BSP_SCHEDULE_DELAY", "")

      {:ok, pid} =
        Otel.SDK.Trace.BatchProcessor.start_link(%{
          exporter: {Otel.SDK.Trace.BatchProcessorTest.TestExporter, %{test_pid: self()}},
          name: :bsp_empty_test
        })

      state = :sys.get_state(pid)
      assert state.scheduled_delay_ms == 5000
      GenServer.stop(pid)
    end

    test "unparseable env var uses default" do
      System.put_env("OTEL_BSP_SCHEDULE_DELAY", "not_a_number")

      {:ok, pid} =
        Otel.SDK.Trace.BatchProcessor.start_link(%{
          exporter: {Otel.SDK.Trace.BatchProcessorTest.TestExporter, %{test_pid: self()}},
          name: :bsp_invalid_test
        })

      state = :sys.get_state(pid)
      assert state.scheduled_delay_ms == 5000
      GenServer.stop(pid)
    end
  end
end
