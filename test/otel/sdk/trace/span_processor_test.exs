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

  @spec shutdown(
          config :: Otel.SDK.Trace.SpanProcessor.config(),
          timeout :: timeout()
        ) :: :ok | {:error, term()}
  @impl true
  def shutdown(_config, _timeout \\ 5_000), do: :ok

  @spec force_flush(
          config :: Otel.SDK.Trace.SpanProcessor.config(),
          timeout :: timeout()
        ) :: :ok | {:error, term()}
  @impl true
  def force_flush(_config, _timeout \\ 5_000), do: :ok
end

defmodule Otel.SDK.Trace.SpanProcessorTest do
  use ExUnit.Case

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)

    :ok
  end

  defp tracer_for(scope_name) do
    {_module, tracer_config} =
      Otel.SDK.Trace.TracerProvider.get_tracer(
        Otel.SDK.Trace.TracerProvider,
        %Otel.API.InstrumentationScope{name: scope_name}
      )

    {Otel.SDK.Trace.Tracer, tracer_config}
  end

  describe "on_start integration" do
    test "processor on_start is called when span is created" do
      restart_sdk(
        trace: [
          processors: [{Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}}]
        ]
      )

      tracer = tracer_for("test_lib")
      Otel.SDK.Trace.Tracer.start_span(Otel.API.Ctx.new(), tracer, "processor_test", [])

      assert_receive {:on_start, "processor_test"}
    end

    test "multiple processors are called in order" do
      restart_sdk(
        trace: [
          processors: [
            {Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}},
            {Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}}
          ]
        ]
      )

      tracer = tracer_for("test_lib")
      Otel.SDK.Trace.Tracer.start_span(Otel.API.Ctx.new(), tracer, "multi_processor", [])

      assert_receive {:on_start, "multi_processor"}
      assert_receive {:on_start, "multi_processor"}
    end

    test "dropped spans do not trigger on_start" do
      restart_sdk(
        trace: [
          sampler: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}},
          processors: [{Otel.SDK.Trace.SpanProcessorTest.TestProcessor, %{test_pid: self()}}]
        ]
      )

      tracer = tracer_for("test_lib")
      Otel.SDK.Trace.Tracer.start_span(Otel.API.Ctx.new(), tracer, "dropped_span", [])

      refute_receive {:on_start, _}
    end
  end
end
