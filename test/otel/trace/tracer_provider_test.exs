defmodule Otel.Trace.TracerProviderTest do
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

  defp restart_sdk(env), do: Otel.TestSupport.restart_with(env)

  setup do
    restart_sdk(trace: [processors: []])
    %{provider: Otel.Trace.TracerProvider}
  end

  test "registers as global TracerProvider on boot", %{provider: p} do
    assert Process.alive?(Process.whereis(p))
  end

  describe "get_tracer/2" do
    test "returns %Tracer{} struct carrying scope, span_limits",
         %{provider: p} do
      tracer =
        Otel.Trace.TracerProvider.get_tracer(p, %Otel.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0",
          schema_url: "https://example.com"
        })

      assert %Otel.Trace.Tracer{} = tracer

      assert %Otel.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = tracer.scope

      assert %Otel.Trace.SpanLimits{} = tracer.span_limits
    end

    # Spec trace/sdk.md L125-L130 — invalid Tracer name SHOULD log a
    # warning, but the original value MUST be preserved.
    test "empty Tracer name → warns; valid name is silent", %{provider: p} do
      log =
        capture_log(fn ->
          Otel.Trace.TracerProvider.get_tracer(p, %Otel.InstrumentationScope{name: ""})
        end)

      assert log =~ "invalid Tracer name"

      silent =
        capture_log(fn ->
          Otel.Trace.TracerProvider.get_tracer(p, %Otel.InstrumentationScope{name: "ok"})
        end)

      refute silent =~ "invalid Tracer name"
    end
  end

  describe "shutdown/1 + force_flush/1" do
    test "no-processor provider: first shutdown :ok; subsequent ops → :already_shutdown; get_tracer → no-op tracer",
         %{provider: p} do
      assert :ok = Otel.Trace.TracerProvider.shutdown(p)

      assert {:error, :already_shutdown} = Otel.Trace.TracerProvider.shutdown(p)
      assert {:error, :already_shutdown} = Otel.Trace.TracerProvider.force_flush(p)

      assert %Otel.Trace.Tracer{processors_key: nil} =
               Otel.Trace.TracerProvider.get_tracer(p, %Otel.InstrumentationScope{name: "lib"})
    end

    test "lifecycle + introspection facades stay graceful when the provider isn't running" do
      # When the SDK Application is stopped, the provider
      # GenServer is never started. Every public-facing facade
      # that does `GenServer.call/3` MUST stay graceful so caller
      # code can keep its plumbing in place without guarding
      # each call.
      Otel.TestSupport.stop_all()
      refute GenServer.whereis(Otel.Trace.TracerProvider)

      assert :ok =
               Otel.Trace.TracerProvider.force_flush(Otel.Trace.TracerProvider, 1_000)

      assert :ok = Otel.Trace.TracerProvider.shutdown(Otel.Trace.TracerProvider, 1_000)

      assert %Otel.Resource{} =
               Otel.Trace.TracerProvider.resource(Otel.Trace.TracerProvider)

      assert %{} = Otel.Trace.TracerProvider.config(Otel.Trace.TracerProvider)

      Application.ensure_all_started(:otel)
    end

    test "invokes shutdown / force_flush on every registered processor" do
      restart_sdk(trace: [processors: [{OkProcessor, %{}}, {OkProcessor, %{}}]])
      assert :ok = Otel.Trace.TracerProvider.shutdown(Otel.Trace.TracerProvider)

      restart_sdk(trace: [processors: [{OkProcessor, %{}}]])
      assert :ok = Otel.Trace.TracerProvider.force_flush(Otel.Trace.TracerProvider)
    end

    test "errors from processors are collected per-processor" do
      restart_sdk(trace: [processors: [{OkProcessor, %{}}, {FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :shutdown_failed}]} =
               Otel.Trace.TracerProvider.shutdown(Otel.Trace.TracerProvider)

      restart_sdk(trace: [processors: [{FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :flush_failed}]} =
               Otel.Trace.TracerProvider.force_flush(Otel.Trace.TracerProvider)
    end
  end

  describe "processor crash handling" do
    test "killing a process-backed processor removes it from state and persistent_term registry" do
      restart_sdk(trace: [processors: [{LinkableProcessor, %{}}, {LinkableProcessor, %{}}]])
      provider = Otel.Trace.TracerProvider

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

      :ok = Otel.Trace.TracerProvider.shutdown(p)
      send(Process.whereis(p), {:EXIT, self(), :late})
      assert match?(%{shut_down: true}, :sys.get_state(p))
    end
  end

  test "resource/1 + config/1 return the boot-time provider state", %{provider: p} do
    assert %Otel.Resource{} = Otel.Trace.TracerProvider.resource(p)

    config = Otel.Trace.TracerProvider.config(p)

    for field <- [:processors, :resource], do: assert(Map.has_key?(config, field))
  end

  describe "boot-time processor wiring" do
    defmodule FakeExporter do
      @moduledoc false
      def init(_), do: {:ok, %{}}
      def export(_, _, _), do: :ok
      def force_flush(_), do: :ok
      def shutdown(_), do: :ok
    end

    # Regression: `function_exported?(module, :start_link, 1)` returns
    # false for an unloaded module, which silently demotes
    # `SpanProcessor` to module-only. Code.ensure_loaded/1 in
    # `start_processor/2` prevents this. Resource must reach the
    # processor's init config so OTLP encoding finds non-empty
    # `attributes` at export time.
    test "Batch processor receives a pid and the provider resource via init config" do
      :code.purge(Otel.Trace.SpanProcessor)
      :code.delete(Otel.Trace.SpanProcessor)

      restart_sdk(
        trace: [processors: [{Otel.Trace.SpanProcessor, %{exporter: {FakeExporter, %{}}}}]]
      )

      [%{module: Otel.Trace.SpanProcessor, pid: pid, callback_config: cb}] =
        :sys.get_state(Otel.Trace.TracerProvider).processors

      assert is_pid(pid) and Process.alive?(pid)
      assert cb == %{pid: pid}
      assert %Otel.Resource{} = :sys.get_state(pid).resource
    end
  end
end
