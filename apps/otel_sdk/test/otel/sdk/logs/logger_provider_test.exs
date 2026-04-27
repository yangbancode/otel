defmodule Otel.SDK.Logs.LoggerProviderTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  setup do
    restart_sdk(logs: [exporter: :none])
    %{provider: Otel.SDK.Logs.LoggerProvider}
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

    test "registers as global provider", %{provider: provider} do
      assert Otel.API.Logs.LoggerProvider.get_provider() ==
               {Otel.SDK.Logs.LoggerProvider, provider}
    end
  end

  describe "get_logger/2,3,4" do
    test "returns SDK logger", %{provider: provider} do
      {module, _config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.SDK.Logs.Logger
    end

    test "logger has correct scope", %{provider: provider} do
      {_module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0"
        })

      assert config.scope.name == "my_lib"
      assert config.scope.version == "1.0.0"
    end

    test "logger has resource", %{provider: provider} do
      {_module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert %Otel.SDK.Resource{} = config.resource
    end

    test "logger has processors_key for dynamic access", %{provider: provider} do
      {_module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert Map.has_key?(config, :processors_key)
    end

    test "returns working logger for empty name (original value preserved)", %{provider: provider} do
      {module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
          name: ""
        })

      assert module == Otel.SDK.Logs.Logger
      assert config.scope.name == ""
    end

    test "logs a warning for empty Logger name (spec L78-L81)", %{provider: provider} do
      log =
        capture_log(fn ->
          Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
            name: ""
          })
        end)

      assert log =~ "invalid Logger name"
    end

    test "no warning for a valid Logger name", %{provider: provider} do
      log =
        capture_log(fn ->
          Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
            name: "my_lib"
          })
        end)

      refute log =~ "invalid Logger name"
    end

    test "accepts pid handle (alive? pid branch)", %{provider: provider} do
      pid = Process.whereis(provider)

      {module, _} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{name: "lib"})

      assert module == Otel.SDK.Logs.Logger
    end
  end

  describe "resource/1" do
    test "returns the resource", %{provider: provider} do
      resource = Otel.SDK.Logs.LoggerProvider.resource(provider)
      assert %Otel.SDK.Resource{} = resource
    end
  end

  describe "config/1" do
    test "returns the configuration", %{provider: provider} do
      config = Otel.SDK.Logs.LoggerProvider.config(provider)
      assert is_map(config)
      assert Map.has_key?(config, :resource)
      assert Map.has_key?(config, :processors)
    end
  end

  describe "shutdown/1" do
    test "returns :ok on first shutdown", %{provider: provider} do
      assert :ok == Otel.SDK.Logs.LoggerProvider.shutdown(provider)
    end

    test "returns error on second shutdown", %{provider: provider} do
      Otel.SDK.Logs.LoggerProvider.shutdown(provider)
      assert {:error, :already_shutdown} == Otel.SDK.Logs.LoggerProvider.shutdown(provider)
    end

    test "returns noop logger after shutdown", %{provider: provider} do
      Otel.SDK.Logs.LoggerProvider.shutdown(provider)

      {module, _config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.API.Logs.Logger.Noop
    end
  end

  describe "force_flush/1" do
    test "returns :ok with no processors", %{provider: provider} do
      assert :ok == Otel.SDK.Logs.LoggerProvider.force_flush(provider)
    end

    test "returns error after shutdown", %{provider: provider} do
      Otel.SDK.Logs.LoggerProvider.shutdown(provider)
      assert {:error, :already_shutdown} == Otel.SDK.Logs.LoggerProvider.force_flush(provider)
    end
  end

  describe "with processors" do
    defmodule TestProcessor do
      @moduledoc false
      def on_emit(record, _ctx, config) do
        send(config.test_pid, {:on_emit, record})
        :ok
      end

      def shutdown(_config, _timeout \\ 5000), do: :ok
      def force_flush(_config, _timeout \\ 5000), do: :ok
    end

    defmodule ShutdownProcessor do
      @moduledoc false
      def on_emit(_record, _ctx, _config), do: :ok

      def shutdown(config, _timeout \\ 5000) do
        send(config.test_pid, :processor_shutdown)
        :ok
      end

      def force_flush(_config, _timeout \\ 5000), do: :ok
    end

    defmodule FlushProcessor do
      @moduledoc false
      def on_emit(_record, _ctx, _config), do: :ok
      def shutdown(_config, _timeout \\ 5000), do: :ok

      def force_flush(config, _timeout \\ 5000) do
        send(config.test_pid, :processor_force_flush)
        :ok
      end
    end

    defmodule FailProcessor do
      @moduledoc false
      def on_emit(_record, _ctx, _config), do: :ok
      def shutdown(_config, _timeout \\ 5000), do: {:error, :shutdown_failed}
      def force_flush(_config, _timeout \\ 5000), do: {:error, :flush_failed}
    end

    test "shutdown invokes processor shutdown" do
      restart_sdk(logs: [processors: [{ShutdownProcessor, %{test_pid: self()}}]])

      Otel.SDK.Logs.LoggerProvider.shutdown(Otel.SDK.Logs.LoggerProvider)
      assert_receive :processor_shutdown
    end

    test "force_flush invokes processor force_flush" do
      restart_sdk(logs: [processors: [{FlushProcessor, %{test_pid: self()}}]])

      Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)
      assert_receive :processor_force_flush
    end

    test "shutdown collects errors from failing processors" do
      restart_sdk(logs: [processors: [{FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :shutdown_failed}]} =
               Otel.SDK.Logs.LoggerProvider.shutdown(Otel.SDK.Logs.LoggerProvider)
    end

    test "force_flush collects errors from failing processors" do
      restart_sdk(logs: [processors: [{FailProcessor, %{}}]])

      assert {:error, [{FailProcessor, :flush_failed}]} =
               Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)
    end
  end

  describe "EXIT signal handling" do
    test "ignores EXIT from unmanaged process", %{provider: provider} do
      send(Process.whereis(provider), {:EXIT, self(), :unrelated})
      assert is_map(:sys.get_state(provider))
    end

    test "ignores late EXIT after shutdown", %{provider: provider} do
      :ok = Otel.SDK.Logs.LoggerProvider.shutdown(provider)
      send(Process.whereis(provider), {:EXIT, self(), :late})
      assert match?(%{shut_down: true}, :sys.get_state(provider))
    end
  end

  describe "provider-owned processor lifecycle" do
    defmodule LinkableProcessor do
      @moduledoc false
      use GenServer

      def start_link(config), do: GenServer.start_link(__MODULE__, config)

      @impl true
      def init(config), do: {:ok, config}

      def on_emit(_record, _ctx, _config), do: :ok
      def shutdown(_config, _timeout \\ 5000), do: :ok
      def force_flush(_config, _timeout \\ 5000), do: :ok
    end

    defmodule ModuleOnlyProcessor do
      @moduledoc false
      def on_emit(_record, _ctx, _config), do: :ok
      def shutdown(_config, _timeout \\ 5000), do: :ok
      def force_flush(_config, _timeout \\ 5000), do: :ok
    end

    test "starts process-backed processors and removes them when they die" do
      restart_sdk(logs: [processors: [{LinkableProcessor, %{}}]])
      provider = Otel.SDK.Logs.LoggerProvider

      [entry] = Otel.SDK.Logs.LoggerProvider.config(provider).processors
      assert is_pid(entry.pid)
      assert entry.callback_config == %{pid: entry.pid}

      proc_pid = entry.pid
      proc_ref = Process.monitor(proc_pid)
      Process.exit(proc_pid, :kill)
      assert_receive {:DOWN, ^proc_ref, :process, ^proc_pid, :killed}

      # Round-trip a call so the LoggerProvider has finished its own EXIT handler.
      _ = Otel.SDK.Logs.LoggerProvider.config(provider)
      assert Process.alive?(Process.whereis(provider))
      assert Otel.SDK.Logs.LoggerProvider.config(provider).processors == []
    end

    test "module-only processor is registered without a PID" do
      restart_sdk(logs: [processors: [{ModuleOnlyProcessor, %{test_pid: self()}}]])
      provider = Otel.SDK.Logs.LoggerProvider

      [entry] = Otel.SDK.Logs.LoggerProvider.config(provider).processors
      assert entry.pid == nil
      # Callback config is the user's verbatim init_config for module-only.
      assert entry.callback_config == %{test_pid: self()}
    end
  end
end
