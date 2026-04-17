defmodule Otel.SDK.Trace.SimpleProcessorTest.TestExporter do
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
end

defmodule Otel.SDK.Trace.SimpleProcessorTest do
  use ExUnit.Case

  @sampled_span %Otel.SDK.Trace.Span{
    trace_id: Otel.API.Trace.TraceId.new(<<1::128>>),
    span_id: Otel.API.Trace.SpanId.new(<<1::64>>),
    name: "sampled_span",
    trace_flags: 1,
    is_recording: true
  }

  @unsampled_span %Otel.SDK.Trace.Span{
    trace_id: Otel.API.Trace.TraceId.new(<<2::128>>),
    span_id: Otel.API.Trace.SpanId.new(<<2::64>>),
    name: "unsampled_span",
    trace_flags: 0,
    is_recording: true
  }

  setup do
    config = %{
      exporter: {Otel.SDK.Trace.SimpleProcessorTest.TestExporter, %{test_pid: self()}},
      name: :"simple_processor_#{System.unique_integer([:positive])}"
    }

    {:ok, _pid} = Otel.SDK.Trace.SimpleProcessor.start_link(config)
    %{config: %{reg_name: config.name}}
  end

  describe "on_start/3" do
    test "returns span unchanged", %{config: config} do
      span = Otel.SDK.Trace.SimpleProcessor.on_start(%{}, @sampled_span, config)
      assert span == @sampled_span
    end
  end

  describe "on_end/2" do
    test "exports sampled span immediately", %{config: config} do
      assert :ok = Otel.SDK.Trace.SimpleProcessor.on_end(@sampled_span, config)
      assert_receive {:exported, ["sampled_span"]}
    end

    test "drops unsampled span without exporting", %{config: config} do
      assert :dropped = Otel.SDK.Trace.SimpleProcessor.on_end(@unsampled_span, config)
      refute_receive {:exported, _}
    end
  end

  describe "shutdown/1" do
    test "calls exporter shutdown", %{config: config} do
      assert :ok = Otel.SDK.Trace.SimpleProcessor.shutdown(config)
      assert_receive :exporter_shutdown
    end

    test "drops spans after shutdown", %{config: config} do
      Otel.SDK.Trace.SimpleProcessor.shutdown(config)
      assert :dropped = Otel.SDK.Trace.SimpleProcessor.on_end(@sampled_span, config)
    end
  end

  describe "force_flush/1" do
    test "returns :ok (no-op for simple processor)", %{config: config} do
      assert :ok = Otel.SDK.Trace.SimpleProcessor.force_flush(config)
    end
  end

  describe "exporter :ignore" do
    test "drops all spans when exporter returns :ignore" do
      config = %{
        exporter: {Otel.SDK.Trace.SimpleProcessorTest.IgnoreExporter, %{}},
        name: :"ignore_processor_#{System.unique_integer([:positive])}"
      }

      defmodule IgnoreExporter do
        @behaviour Otel.SDK.Trace.SpanExporter
        @impl true
        def init(_config), do: :ignore
        @impl true
        def export(_spans, _resource, _state), do: :ok
        @impl true
        def shutdown(_state), do: :ok
      end

      {:ok, _pid} = Otel.SDK.Trace.SimpleProcessor.start_link(config)

      assert :dropped =
               Otel.SDK.Trace.SimpleProcessor.on_end(@sampled_span, %{reg_name: config.name})

      assert :ok = Otel.SDK.Trace.SimpleProcessor.shutdown(%{reg_name: config.name})
    end
  end
end
