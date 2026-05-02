defmodule Otel.SDK.Logs.LoggerProviderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    restart_sdk(logs: [processors: []])
    %{provider: Otel.SDK.Logs.LoggerProvider}
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

  test "registers itself as the global LoggerProvider; the GenServer is alive", %{provider: p} do
    assert Process.alive?(Process.whereis(p))
    assert Otel.API.Logs.LoggerProvider.get_provider() == {Otel.SDK.Logs.LoggerProvider, p}
  end

  describe "get_logger/2" do
    test "returns {SDK.Logger, config} carrying scope, resource, and processors_key", %{
      provider: p
    } do
      {module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(p, %Otel.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0"
        })

      assert module == Otel.SDK.Logs.Logger
      assert config.scope.name == "my_lib"
      assert config.scope.version == "1.0.0"
      assert %Otel.Resource{} = config.resource
      assert Map.has_key?(config, :processors_key)
    end

    test "accepts a pid handle and behaves identically to the registered name", %{provider: p} do
      pid = Process.whereis(p)

      {Otel.SDK.Logs.Logger, _} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.InstrumentationScope{name: "lib"})
    end

    # Spec logs/api.md L78-L81 — invalid Logger name SHOULD log a
    # warning, but the original value MUST be preserved.
    test "empty Logger name → warns; original name preserved on the returned logger", %{
      provider: p
    } do
      log =
        capture_log(fn ->
          {Otel.SDK.Logs.Logger, config} =
            Otel.SDK.Logs.LoggerProvider.get_logger(p, %Otel.InstrumentationScope{name: ""})

          assert config.scope.name == ""
        end)

      assert log =~ "invalid Logger name"

      silent =
        capture_log(fn ->
          Otel.SDK.Logs.LoggerProvider.get_logger(p, %Otel.InstrumentationScope{name: "ok"})
        end)

      refute silent =~ "invalid Logger name"
    end
  end

  test "resource/1 + config/1 return the boot-time provider state", %{provider: p} do
    assert %Otel.Resource{} = Otel.SDK.Logs.LoggerProvider.resource(p)

    config = Otel.SDK.Logs.LoggerProvider.config(p)
    assert is_map(config)
    assert Map.has_key?(config, :resource)
    assert Map.has_key?(config, :processors)
  end

  describe "shutdown/1 + force_flush/1" do
    test "no-processor provider: first shutdown :ok; subsequent ops → :already_shutdown; get_logger → Noop",
         %{provider: p} do
      assert :ok = Otel.SDK.Logs.LoggerProvider.shutdown(p)

      assert {:error, :already_shutdown} = Otel.SDK.Logs.LoggerProvider.shutdown(p)
      assert {:error, :already_shutdown} = Otel.SDK.Logs.LoggerProvider.force_flush(p)

      {Otel.API.Logs.Logger.Noop, _} =
        Otel.SDK.Logs.LoggerProvider.get_logger(p, %Otel.InstrumentationScope{name: "lib"})
    end

    test "lifecycle + introspection facades stay graceful when the provider isn't running" do
      Application.stop(:otel)
      refute GenServer.whereis(Otel.SDK.Logs.LoggerProvider)

      assert :ok =
               Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider, 1_000)

      assert :ok = Otel.SDK.Logs.LoggerProvider.shutdown(Otel.SDK.Logs.LoggerProvider, 1_000)

      assert %Otel.Resource{} =
               Otel.SDK.Logs.LoggerProvider.resource(Otel.SDK.Logs.LoggerProvider)

      assert %{} = Otel.SDK.Logs.LoggerProvider.config(Otel.SDK.Logs.LoggerProvider)

      Application.ensure_all_started(:otel)
    end
  end

  describe "processor lifecycle delegation" do
    defmodule ShutdownProcessor do
      @moduledoc false
      def on_emit(_r, _c, _cfg), do: :ok
      def shutdown(%{test_pid: pid}, _timeout \\ 5000), do: send(pid, :processor_shutdown) && :ok
      def force_flush(_cfg, _t \\ 5000), do: :ok
    end

    defmodule FlushProcessor do
      @moduledoc false
      def on_emit(_r, _c, _cfg), do: :ok
      def shutdown(_cfg, _t \\ 5000), do: :ok

      def force_flush(%{test_pid: pid}, _t \\ 5000),
        do: send(pid, :processor_force_flush) && :ok
    end

    defmodule FailProcessor do
      @moduledoc false
      def on_emit(_r, _c, _cfg), do: :ok
      def shutdown(_cfg, _t \\ 5000), do: {:error, :shutdown_failed}
      def force_flush(_cfg, _t \\ 5000), do: {:error, :flush_failed}
    end

    test "shutdown / force_flush invoke the corresponding processor callback" do
      restart_sdk(logs: [processors: [{ShutdownProcessor, %{test_pid: self()}}]])
      Otel.SDK.Logs.LoggerProvider.shutdown(Otel.SDK.Logs.LoggerProvider)
      assert_receive :processor_shutdown

      restart_sdk(logs: [processors: [{FlushProcessor, %{test_pid: self()}}]])
      Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)
      assert_receive :processor_force_flush
    end

    test "errors from processors are collected and returned per-processor" do
      restart_sdk(logs: [processors: [{FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :shutdown_failed}]} =
               Otel.SDK.Logs.LoggerProvider.shutdown(Otel.SDK.Logs.LoggerProvider)

      restart_sdk(logs: [processors: [{FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :flush_failed}]} =
               Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)
    end
  end

  describe "provider-owned processor lifecycle" do
    defmodule LinkableProcessor do
      @moduledoc false
      use GenServer

      def start_link(config), do: GenServer.start_link(__MODULE__, config)

      @impl true
      def init(config), do: {:ok, config}

      def on_emit(_r, _c, _cfg), do: :ok
      def shutdown(_cfg, _t \\ 5000), do: :ok
      def force_flush(_cfg, _t \\ 5000), do: :ok
    end

    defmodule ModuleOnlyProcessor do
      @moduledoc false
      def on_emit(_r, _c, _cfg), do: :ok
      def shutdown(_cfg, _t \\ 5000), do: :ok
      def force_flush(_cfg, _t \\ 5000), do: :ok
    end

    test "process-backed processor is supervised; killing it removes it from the registry" do
      restart_sdk(logs: [processors: [{LinkableProcessor, %{}}]])
      provider = Otel.SDK.Logs.LoggerProvider

      [entry] = Otel.SDK.Logs.LoggerProvider.config(provider).processors
      assert is_pid(entry.pid)
      assert entry.callback_config == %{pid: entry.pid}

      ref = Process.monitor(entry.pid)
      Process.exit(entry.pid, :kill)
      assert_receive {:DOWN, ^ref, :process, _, :killed}

      # Round-trip a call so the provider has handled its EXIT.
      _ = Otel.SDK.Logs.LoggerProvider.config(provider)
      assert Process.alive?(Process.whereis(provider))
      assert Otel.SDK.Logs.LoggerProvider.config(provider).processors == []
    end

    test "module-only processor registers without a PID; carries verbatim init_config" do
      restart_sdk(logs: [processors: [{ModuleOnlyProcessor, %{test_pid: self()}}]])
      [entry] = Otel.SDK.Logs.LoggerProvider.config(Otel.SDK.Logs.LoggerProvider).processors
      assert entry.pid == nil
      assert entry.callback_config == %{test_pid: self()}
    end

    defmodule FakeExporter do
      @moduledoc false
      @behaviour Otel.SDK.Logs.LogRecordExporter
      @impl true
      def init(_), do: {:ok, %{}}
      @impl true
      def export(_, _), do: :ok
      @impl true
      def force_flush(_), do: :ok
      @impl true
      def shutdown(_), do: :ok
    end

    # Regression: `function_exported?(module, :start_link, 1)` returns
    # false for an unloaded module, which silently demotes
    # `LogRecordProcessor` to module-only and crashes
    # `on_emit/3` because the callback config has no `:pid`.
    # `Code.ensure_loaded/1` in `start_processor/1` prevents this.
    test "Batch processor receives a pid when configured by the provider" do
      :code.purge(Otel.SDK.Logs.LogRecordProcessor)
      :code.delete(Otel.SDK.Logs.LogRecordProcessor)

      restart_sdk(logs: [processor: :batch, exporter: {FakeExporter, %{}}])

      [%{module: Otel.SDK.Logs.LogRecordProcessor, pid: pid, callback_config: cb}] =
        :sys.get_state(Otel.SDK.Logs.LoggerProvider).processors

      assert is_pid(pid) and Process.alive?(pid)
      assert cb == %{pid: pid}
    end
  end

  describe "EXIT signal handling" do
    test "ignores EXIT from unmanaged processes; ignores late EXIT after shutdown",
         %{provider: p} do
      send(Process.whereis(p), {:EXIT, self(), :unrelated})
      assert is_map(:sys.get_state(p))

      :ok = Otel.SDK.Logs.LoggerProvider.shutdown(p)
      send(Process.whereis(p), {:EXIT, self(), :late})
      assert match?(%{shut_down: true}, :sys.get_state(p))
    end
  end
end
