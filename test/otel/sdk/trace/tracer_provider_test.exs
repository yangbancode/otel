defmodule Otel.SDK.Trace.TracerProviderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule OkProcessor do
    @moduledoc false
    def shutdown(_cfg, _t \\ 5_000), do: :ok
    def force_flush(_cfg, _t \\ 5_000), do: :ok
  end

  defmodule FailProcessor do
    @moduledoc false
    def shutdown(_cfg, _t \\ 5_000), do: {:error, :shutdown_failed}
    def force_flush(_cfg, _t \\ 5_000), do: {:error, :flush_failed}
  end

  defmodule LinkableProcessor do
    @moduledoc false
    use GenServer

    def start_link(config), do: GenServer.start_link(__MODULE__, config)

    @impl true
    def init(config), do: {:ok, config}

    def on_start(_ctx, span, _cfg), do: span
    def on_end(_span, _cfg), do: :ok
    def shutdown(_cfg, _t \\ 5_000), do: :ok
    def force_flush(_cfg, _t \\ 5_000), do: :ok
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

  setup do
    restart_sdk(trace: [exporter: :none])
    %{provider: Otel.SDK.Trace.TracerProvider}
  end

  test "registers as global TracerProvider on boot", %{provider: p} do
    assert Process.alive?(Process.whereis(p))
    assert Otel.API.Trace.TracerProvider.get_provider() == {Otel.SDK.Trace.TracerProvider, p}
  end

  describe "get_tracer/2" do
    test "returns {SDK.Tracer, config} carrying scope, sampler, id_generator, span_limits",
         %{provider: p} do
      {module, config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(p, %Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0",
          schema_url: "https://example.com"
        })

      assert module == Otel.SDK.Trace.Tracer

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = config.scope

      # Sampler is initialized to {module, description, opts}.
      assert {Otel.SDK.Trace.Sampler.ParentBased, _desc, _opts} = config.sampler
      assert config.id_generator == Otel.SDK.Trace.IdGenerator.Default
      assert %Otel.SDK.Trace.SpanLimits{} = config.span_limits
    end

    # Spec trace/sdk.md L125-L130 — invalid Tracer name SHOULD log a
    # warning, but the original value MUST be preserved.
    test "empty Tracer name → warns; valid name is silent", %{provider: p} do
      log =
        capture_log(fn ->
          Otel.SDK.Trace.TracerProvider.get_tracer(p, %Otel.API.InstrumentationScope{name: ""})
        end)

      assert log =~ "invalid Tracer name"

      silent =
        capture_log(fn ->
          Otel.SDK.Trace.TracerProvider.get_tracer(p, %Otel.API.InstrumentationScope{name: "ok"})
        end)

      refute silent =~ "invalid Tracer name"
    end
  end

  describe "shutdown/1 + force_flush/1" do
    test "no-processor provider: first shutdown :ok; subsequent ops → :already_shutdown; get_tracer → Noop",
         %{provider: p} do
      assert :ok = Otel.SDK.Trace.TracerProvider.shutdown(p)

      assert {:error, :already_shutdown} = Otel.SDK.Trace.TracerProvider.shutdown(p)
      assert {:error, :already_shutdown} = Otel.SDK.Trace.TracerProvider.force_flush(p)

      {Otel.API.Trace.Tracer.Noop, _} =
        Otel.SDK.Trace.TracerProvider.get_tracer(p, %Otel.API.InstrumentationScope{name: "lib"})
    end

    test "invokes shutdown / force_flush on every registered processor" do
      restart_sdk(trace: [processors: [{OkProcessor, %{}}, {OkProcessor, %{}}]])
      assert :ok = Otel.SDK.Trace.TracerProvider.shutdown(Otel.SDK.Trace.TracerProvider)

      restart_sdk(trace: [processors: [{OkProcessor, %{}}]])
      assert :ok = Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)
    end

    test "errors from processors are collected per-processor" do
      restart_sdk(trace: [processors: [{OkProcessor, %{}}, {FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :shutdown_failed}]} =
               Otel.SDK.Trace.TracerProvider.shutdown(Otel.SDK.Trace.TracerProvider)

      restart_sdk(trace: [processors: [{FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :flush_failed}]} =
               Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)
    end
  end

  describe "processor crash handling" do
    test "killing a process-backed processor removes it from state and persistent_term registry" do
      restart_sdk(trace: [processors: [{LinkableProcessor, %{}}, {LinkableProcessor, %{}}]])
      provider = Otel.SDK.Trace.TracerProvider

      [%{pid: victim}, %{pid: survivor}] = :sys.get_state(provider).processors
      key = :sys.get_state(provider).processors_key
      assert length(:persistent_term.get(key)) == 2

      ref = Process.monitor(victim)
      Process.exit(victim, :kill)
      assert_receive {:DOWN, ^ref, :process, ^victim, :killed}

      # Round-trip a call so the provider has run its EXIT handler.
      _ = :sys.get_state(provider)
      assert Process.alive?(Process.whereis(provider))
      assert [%{pid: ^survivor}] = :sys.get_state(provider).processors
      assert [{LinkableProcessor, _}] = :persistent_term.get(key)
    end

    test "ignores EXIT from unmanaged processes; ignores late EXIT after shutdown",
         %{provider: p} do
      send(Process.whereis(p), {:EXIT, self(), :unrelated})
      assert is_map(:sys.get_state(p))

      :ok = Otel.SDK.Trace.TracerProvider.shutdown(p)
      send(Process.whereis(p), {:EXIT, self(), :late})
      assert match?(%{shut_down: true}, :sys.get_state(p))
    end
  end

  test "resource/1 + config/1 return the boot-time provider state", %{provider: p} do
    assert %Otel.SDK.Resource{} = Otel.SDK.Trace.TracerProvider.resource(p)

    config = Otel.SDK.Trace.TracerProvider.config(p)

    for field <- [:sampler, :processors, :resource], do: assert(Map.has_key?(config, field))
  end
end
