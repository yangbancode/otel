defmodule Otel.SDK.Trace.SpanProcessorTest.TestProcessor do
  @behaviour Otel.SDK.Trace.SpanProcessor

  @spec on_start(
          ctx :: Otel.API.Ctx.t(),
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: Otel.SDK.Trace.Span.t()
  @impl true
  def on_start(_ctx, span, %{test_pid: pid}) do
    send(pid, {:on_start, span.name})
    span
  end

  @spec on_end(
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: :ok | :dropped | {:error, term()}
  @impl true
  def on_end(span, %{test_pid: pid}) do
    send(pid, {:on_end, span.name})
    :ok
  end

  @spec shutdown(config :: Otel.SDK.Trace.SpanProcessor.config()) :: :ok | {:error, term()}
  @impl true
  def shutdown(_config), do: :ok

  @spec force_flush(config :: Otel.SDK.Trace.SpanProcessor.config()) :: :ok | {:error, term()}
  @impl true
  def force_flush(_config), do: :ok
end

defmodule Otel.SDK.Trace.SpanProcessorTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  describe "on_start integration" do
    test "processor on_start is called when span is created" do
      {:ok, provider} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}}
            ]
          }
        )

      {_module, tracer_config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(provider, %Otel.API.InstrumentationScope{
          name: "test_lib"
        })

      tracer = {Otel.SDK.Trace.Tracer, tracer_config}
      ctx = %{}

      Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "processor_test", [])

      assert_receive {:on_start, "processor_test"}
    end

    test "multiple processors are called in order" do
      {:ok, provider} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}},
              {Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}}
            ]
          }
        )

      {_module, tracer_config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(provider, %Otel.API.InstrumentationScope{
          name: "test_lib"
        })

      tracer = {Otel.SDK.Trace.Tracer, tracer_config}
      ctx = %{}

      Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "multi_processor", [])

      assert_receive {:on_start, "multi_processor"}
      assert_receive {:on_start, "multi_processor"}
    end

    test "dropped spans do not trigger on_start" do
      {:ok, provider} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            sampler: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}},
            processors: [
              {Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}}
            ]
          }
        )

      {_module, tracer_config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(provider, %Otel.API.InstrumentationScope{
          name: "test_lib"
        })

      tracer = {Otel.SDK.Trace.Tracer, tracer_config}
      ctx = %{}

      Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "dropped_span", [])

      refute_receive {:on_start, _}
    end
  end
end
