defmodule Otel.SDK.Trace.TracerProviderTest.OkProcessor do
  def shutdown(_config, _timeout \\ 5_000), do: :ok
  def force_flush(_config, _timeout \\ 5_000), do: :ok
end

defmodule Otel.SDK.Trace.TracerProviderTest.FailProcessor do
  def shutdown(_config, _timeout \\ 5_000), do: {:error, :shutdown_failed}
  def force_flush(_config, _timeout \\ 5_000), do: {:error, :flush_failed}
end

defmodule Otel.SDK.Trace.TracerProviderTest do
  use ExUnit.Case

  setup do
    restart_sdk(trace: [exporter: :none])
    %{provider: Otel.SDK.Trace.TracerProvider}
  end

  defp restart_sdk(env) do
    Application.stop(:otel_sdk)
    for {pillar, opts} <- env, do: Application.put_env(:otel_sdk, pillar, opts)
    Application.ensure_all_started(:otel_sdk)

    on_exit(fn ->
      Application.stop(:otel_sdk)
      for {pillar, _} <- env, do: Application.delete_env(:otel_sdk, pillar)
    end)

    :ok
  end

  describe "start_link/1" do
    test "starts with default config", %{provider: provider} do
      assert Process.alive?(Process.whereis(provider))
    end

    test "registers as global provider on start", %{provider: provider} do
      assert Otel.API.Trace.TracerProvider.get_provider() ==
               {Otel.SDK.Trace.TracerProvider, provider}
    end

    test "starts with custom config" do
      custom_resource = Otel.SDK.Resource.create(%{"service.name" => "test"})
      restart_sdk(trace: [exporter: :none, resource: custom_resource])
      assert Process.alive?(Process.whereis(Otel.SDK.Trace.TracerProvider))
    end
  end

  describe "get_tracer/2,3,4" do
    test "returns SDK tracer tuple", %{provider: pid} do
      {module, tracer_config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.SDK.Trace.Tracer
      assert %{sampler: _, id_generator: _, span_limits: _, scope: _} = tracer_config
    end

    test "tracer includes instrumentation scope", %{provider: pid} do
      {_module, %{scope: scope}} =
        Otel.SDK.Trace.TracerProvider.get_tracer(pid, %Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0",
          schema_url: "https://example.com"
        })

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = scope
    end

    test "tracer includes initialized sampler", %{provider: pid} do
      {_module, %{sampler: sampler}} =
        Otel.SDK.Trace.TracerProvider.get_tracer(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      # sampler is already initialized {module, description, config} tuple
      assert {Otel.SDK.Trace.Sampler.ParentBased, _desc, _config} = sampler
    end

    test "tracer includes id_generator and span_limits", %{provider: pid} do
      {_module, config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert config.id_generator == Otel.SDK.Trace.IdGenerator.Default
      assert %Otel.SDK.Trace.SpanLimits{} = config.span_limits
    end

    test "logs a warning for empty Tracer name (spec MUST/SHOULD)", %{provider: pid} do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Otel.SDK.Trace.TracerProvider.get_tracer(pid, %Otel.API.InstrumentationScope{name: ""})
        end)

      assert log =~ "invalid Tracer name"
    end

    test "no warning for a valid Tracer name", %{provider: pid} do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Otel.SDK.Trace.TracerProvider.get_tracer(pid, %Otel.API.InstrumentationScope{
            name: "my_lib"
          })
        end)

      refute log =~ "invalid Tracer name"
    end
  end

  describe "shutdown/1" do
    test "returns :ok with no processors", %{provider: pid} do
      assert Otel.SDK.Trace.TracerProvider.shutdown(pid) == :ok
    end

    test "invokes shutdown on all processors" do
      restart_sdk(
        trace: [
          processors: [
            {Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}},
            {Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}}
          ]
        ]
      )

      assert Otel.SDK.Trace.TracerProvider.shutdown(Otel.SDK.Trace.TracerProvider) == :ok
    end

    test "collects errors from failing processors" do
      restart_sdk(
        trace: [
          processors: [
            {Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}},
            {Otel.SDK.Trace.TracerProviderTest.FailProcessor, %{}}
          ]
        ]
      )

      assert {:error, [{Otel.SDK.Trace.TracerProviderTest.FailProcessor, :shutdown_failed}]} =
               Otel.SDK.Trace.TracerProvider.shutdown(Otel.SDK.Trace.TracerProvider)
    end

    test "returns noop tracer after shutdown", %{provider: pid} do
      Otel.SDK.Trace.TracerProvider.shutdown(pid)

      {module, _} =
        Otel.SDK.Trace.TracerProvider.get_tracer(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "second shutdown returns error", %{provider: pid} do
      assert Otel.SDK.Trace.TracerProvider.shutdown(pid) == :ok
      assert Otel.SDK.Trace.TracerProvider.shutdown(pid) == {:error, :already_shutdown}
    end
  end

  describe "force_flush/1" do
    test "returns :ok with no processors", %{provider: pid} do
      assert Otel.SDK.Trace.TracerProvider.force_flush(pid) == :ok
    end

    test "invokes force_flush on all processors" do
      restart_sdk(trace: [processors: [{Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}}]])

      assert Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider) == :ok
    end

    test "collects errors from failing processors" do
      restart_sdk(trace: [processors: [{Otel.SDK.Trace.TracerProviderTest.FailProcessor, %{}}]])

      assert {:error, [{Otel.SDK.Trace.TracerProviderTest.FailProcessor, :flush_failed}]} =
               Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)
    end

    test "returns error after shutdown", %{provider: pid} do
      Otel.SDK.Trace.TracerProvider.shutdown(pid)
      assert Otel.SDK.Trace.TracerProvider.force_flush(pid) == {:error, :already_shutdown}
    end
  end

  describe "processor crash handling" do
    defmodule LinkableProcessor do
      @moduledoc false
      use GenServer

      def start_link(config), do: GenServer.start_link(__MODULE__, config)

      @impl true
      def init(config), do: {:ok, config}

      def on_start(_ctx, span, _config), do: span
      def on_end(_span, _config), do: :ok
      def shutdown(_config, _timeout \\ 5_000), do: :ok
      def force_flush(_config, _timeout \\ 5_000), do: :ok
    end

    test "removes a crashed processor and keeps serving the rest" do
      restart_sdk(trace: [processors: [{LinkableProcessor, %{}}, {LinkableProcessor, %{}}]])

      provider = Otel.SDK.Trace.TracerProvider
      [%{pid: victim} = _entry, %{pid: survivor}] = :sys.get_state(provider).processors
      key = :sys.get_state(provider).processors_key
      assert length(:persistent_term.get(key)) == 2

      ref = Process.monitor(victim)
      Process.exit(victim, :kill)
      assert_receive {:DOWN, ^ref, :process, ^victim, :killed}

      # Round-trip a call so the provider has finished its EXIT handler.
      _ = :sys.get_state(provider)
      assert Process.alive?(Process.whereis(provider))
      assert [%{pid: ^survivor}] = :sys.get_state(provider).processors
      assert [{LinkableProcessor, _}] = :persistent_term.get(key)
    end

    test "ignores EXIT from unmanaged process", %{provider: provider} do
      send(Process.whereis(provider), {:EXIT, self(), :unrelated})
      assert is_map(:sys.get_state(provider))
    end

    test "ignores late EXIT after shutdown", %{provider: provider} do
      :ok = Otel.SDK.Trace.TracerProvider.shutdown(provider)
      send(Process.whereis(provider), {:EXIT, self(), :late})
      assert match?(%{shut_down: true}, :sys.get_state(provider))
    end
  end

  describe "introspection" do
    test "resource/1 returns the configured resource", %{provider: pid} do
      assert %Otel.SDK.Resource{} = Otel.SDK.Trace.TracerProvider.resource(pid)
    end

    test "config/1 returns the runtime config snapshot", %{provider: pid} do
      config = Otel.SDK.Trace.TracerProvider.config(pid)
      assert is_map(config)
      assert Map.has_key?(config, :sampler)
      assert Map.has_key?(config, :processors)
      assert Map.has_key?(config, :resource)
    end
  end
end
