defmodule Otel.SDK.Trace.SpanProcessor.SimpleTest do
  use ExUnit.Case, async: false

  defmodule TestExporter do
    @moduledoc false
    @behaviour Otel.SDK.Trace.SpanExporter

    @impl true
    def init(config), do: {:ok, config}
    @impl true
    def export(spans, _resource, %{test_pid: pid}) do
      send(pid, {:exported, Enum.map(spans, & &1.name)})
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

  defmodule SlowShutdownExporter do
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
    def force_flush(_state), do: :ok
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
    name: "sampled_span",
    trace_flags: 1,
    is_recording: true
  }

  @unsampled %Otel.SDK.Trace.Span{
    trace_id: 2,
    span_id: 2,
    name: "unsampled_span",
    trace_flags: 0,
    is_recording: true
  }

  setup do
    {:ok, pid} =
      Otel.SDK.Trace.SpanProcessor.Simple.start_link(%{
        exporter: {TestExporter, %{test_pid: self()}}
      })

    %{config: %{pid: pid}}
  end

  test "on_start/3 returns the span unchanged", %{config: config} do
    assert Otel.SDK.Trace.SpanProcessor.Simple.on_start(%{}, @sampled, config) == @sampled
  end

  describe "on_end/2 — exports sampled, drops unsampled" do
    test "sampled span is forwarded to the exporter", %{config: config} do
      assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.on_end(@sampled, config)
      assert_receive {:exported, ["sampled_span"]}
    end

    test "unsampled span returns :dropped without exporting", %{config: config} do
      assert :dropped = Otel.SDK.Trace.SpanProcessor.Simple.on_end(@unsampled, config)
      refute_receive {:exported, _}
    end
  end

  test "force_flush/1 is a no-op for the Simple processor", %{config: config} do
    assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.force_flush(config)
  end

  describe "shutdown/1,2" do
    test "calls the exporter's shutdown; later on_end → :dropped", %{config: config} do
      assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.shutdown(config)
      assert_receive :exporter_shutdown

      assert :dropped = Otel.SDK.Trace.SpanProcessor.Simple.on_end(@sampled, config)
    end

    test "second shutdown after the GenServer has stopped → {:error, :already_shutdown}",
         %{config: config} do
      GenServer.stop(config.pid)

      assert {:error, :already_shutdown} =
               Otel.SDK.Trace.SpanProcessor.Simple.shutdown(config)
    end

    test "shutdown that exceeds the GenServer.call timeout → {:error, :timeout}" do
      {:ok, pid} =
        Otel.SDK.Trace.SpanProcessor.Simple.start_link(%{exporter: {SlowShutdownExporter, %{}}})

      assert {:error, :timeout} =
               Otel.SDK.Trace.SpanProcessor.Simple.shutdown(%{pid: pid}, 1)
    end
  end

  test "exporter init/1 returning :ignore → all on_end calls return :dropped" do
    {:ok, pid} =
      Otel.SDK.Trace.SpanProcessor.Simple.start_link(%{exporter: {IgnoreExporter, %{}}})

    config = %{pid: pid}
    assert :dropped = Otel.SDK.Trace.SpanProcessor.Simple.on_end(@sampled, config)
    assert :ok = Otel.SDK.Trace.SpanProcessor.Simple.shutdown(config)
  end
end
