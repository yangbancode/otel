defmodule Otel.SDK.Trace.SpanProcessorTest do
  use ExUnit.Case, async: false

  defmodule TestProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Trace.SpanProcessor

    @impl true
    def on_start(_ctx, span, %{test_pid: pid}) do
      send(pid, {:on_start, span.name})
      span
    end

    @impl true
    def on_end(span, %{test_pid: pid}) do
      send(pid, {:on_end, span.name})
      :ok
    end

    @impl true
    def shutdown(_config, _timeout \\ 5_000), do: :ok
    @impl true
    def force_flush(_config, _timeout \\ 5_000), do: :ok
  end

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)
  end

  defp tracer_for(scope_name) do
    {_module, tracer_config} =
      Otel.SDK.Trace.TracerProvider.get_tracer(
        Otel.SDK.Trace.TracerProvider,
        %Otel.API.InstrumentationScope{name: scope_name}
      )

    {Otel.SDK.Trace.Tracer, tracer_config}
  end

  defp processor(opts \\ %{test_pid: self()}), do: {TestProcessor, opts}

  describe "on_start integration through Tracer.start_span/4" do
    test "calls on_start once per processor in registration order" do
      restart_sdk(trace: [processors: [processor(), processor()]])

      Otel.SDK.Trace.Tracer.start_span(Otel.API.Ctx.new(), tracer_for("lib"), "multi", [])

      assert_receive {:on_start, "multi"}
      assert_receive {:on_start, "multi"}
    end

    test "sampler-dropped spans do NOT trigger on_start" do
      restart_sdk(
        trace: [
          sampler: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}},
          processors: [processor()]
        ]
      )

      Otel.SDK.Trace.Tracer.start_span(Otel.API.Ctx.new(), tracer_for("lib"), "dropped", [])

      refute_receive {:on_start, _}
    end
  end
end
