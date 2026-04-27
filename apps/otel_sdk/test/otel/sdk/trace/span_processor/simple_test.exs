defmodule Otel.SDK.Trace.SpanProcessor.SimpleTest.TestExporter do
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
    send(pid, {:exported, Enum.map(spans, & &1.name)})
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

defmodule Otel.SDK.Trace.SpanProcessor.SimpleTest.SlowShutdownExporter do
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
  def force_flush(_state), do: :ok
end

defmodule Otel.SDK.Trace.SpanProcessor.SimpleTest do
  use ExUnit.Case

  @sampled_span %Otel.SDK.Trace.Span{
    trace_id: 1,
    span_id: 1,
    name: "sampled_span",
    trace_flags: 1,
    is_recording: true
  }

  @unsampled_span %Otel.SDK.Trace.Span{
    trace_id: 2,
    span_id: 2,
    name: "unsampled_span",
    trace_flags: 0,
    is_recording: true
  }

  setup do
    config = %{
      exporter: {Otel.SDK.Trace.SpanProcessor.SimpleTest.TestExporter, %{test_pid: self()}}
    }

    {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Simple.start_link(config)
    %{config: %{pid: pid}}
  end

  describe "on_start/3" do
    test "returns span unchanged", %{config: config} do
      span = Otel.SDK.Trace.SpanProcessor.Simple.on_start(%{}, @sampled_span, config)
      assert span == @sampled_span
    end
  end

  describe "on_end/2" do
    test "exports sampled span immediately", %{config: config} do
      assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.on_end(@sampled_span, config)
      assert_receive {:exported, ["sampled_span"]}
    end

    test "drops unsampled span without exporting", %{config: config} do
      assert :dropped = Otel.SDK.Trace.SpanProcessor.Simple.on_end(@unsampled_span, config)
      refute_receive {:exported, _}
    end
  end

  describe "shutdown/1" do
    test "calls exporter shutdown", %{config: config} do
      assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.shutdown(config)
      assert_receive :exporter_shutdown
    end

    test "drops spans after shutdown", %{config: config} do
      Otel.SDK.Trace.SpanProcessor.Simple.shutdown(config)
      assert :dropped = Otel.SDK.Trace.SpanProcessor.Simple.on_end(@sampled_span, config)
    end

    test "shutdown on stopped processor returns {:error, :already_shutdown}", %{config: config} do
      GenServer.stop(config.pid)
      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.Simple.shutdown(config)
    end

    test "shutdown returns {:error, :timeout} when GenServer.call exceeds timeout" do
      slow_config = %{
        exporter: {Otel.SDK.Trace.SpanProcessor.SimpleTest.SlowShutdownExporter, %{}}
      }

      {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Simple.start_link(slow_config)
      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.Simple.shutdown(%{pid: pid}, 1)
    end
  end

  describe "force_flush/1" do
    test "returns :ok (no-op for simple processor)", %{config: config} do
      assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.force_flush(config)
    end
  end

  describe "exporter :ignore" do
    test "drops all spans when exporter returns :ignore" do
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

      config = %{exporter: {IgnoreExporter, %{}}}
      {:ok, pid} = Otel.SDK.Trace.SpanProcessor.Simple.start_link(config)
      callback_config = %{pid: pid}

      assert :dropped =
               Otel.SDK.Trace.SpanProcessor.Simple.on_end(@sampled_span, callback_config)

      assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.shutdown(callback_config)
    end
  end
end
