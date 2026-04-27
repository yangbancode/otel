defmodule Otel.SDK.Logs.LoggerProviderTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} = Otel.SDK.Logs.LoggerProvider.start_link(config: %{})

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    %{provider: pid}
  end

  describe "start_link/1" do
    test "starts with default config", %{provider: pid} do
      assert Process.alive?(pid)
    end

    test "registers as global provider", %{provider: pid} do
      assert Otel.API.Logs.LoggerProvider.get_provider() == {Otel.SDK.Logs.LoggerProvider, pid}
    end
  end

  describe "get_logger/2,3,4" do
    test "returns SDK logger", %{provider: pid} do
      {module, _config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.SDK.Logs.Logger
    end

    test "logger has correct scope", %{provider: pid} do
      {_module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0"
        })

      assert config.scope.name == "my_lib"
      assert config.scope.version == "1.0.0"
    end

    test "logger has resource", %{provider: pid} do
      {_module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert %Otel.SDK.Resource{} = config.resource
    end

    test "logger has processors_key for dynamic access", %{provider: pid} do
      {_module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert Map.has_key?(config, :processors_key)
    end

    test "returns working logger for empty name (original value preserved)", %{provider: pid} do
      {module, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{name: ""})

      assert module == Otel.SDK.Logs.Logger
      assert config.scope.name == ""
    end

    test "logs a warning for empty Logger name (spec L78-L81)", %{provider: pid} do
      log =
        capture_log(fn ->
          Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{name: ""})
        end)

      assert log =~ "invalid Logger name"
    end

    test "no warning for a valid Logger name", %{provider: pid} do
      log =
        capture_log(fn ->
          Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{
            name: "my_lib"
          })
        end)

      refute log =~ "invalid Logger name"
    end

  end

  describe "resource/1" do
    test "returns the resource", %{provider: pid} do
      resource = Otel.SDK.Logs.LoggerProvider.resource(pid)
      assert %Otel.SDK.Resource{} = resource
    end
  end

  describe "config/1" do
    test "returns the configuration", %{provider: pid} do
      config = Otel.SDK.Logs.LoggerProvider.config(pid)
      assert is_map(config)
      assert Map.has_key?(config, :resource)
      assert Map.has_key?(config, :processors)
    end
  end

  describe "shutdown/1" do
    test "returns :ok on first shutdown", %{provider: pid} do
      assert :ok == Otel.SDK.Logs.LoggerProvider.shutdown(pid)
    end

    test "returns error on second shutdown", %{provider: pid} do
      Otel.SDK.Logs.LoggerProvider.shutdown(pid)
      assert {:error, :already_shutdown} == Otel.SDK.Logs.LoggerProvider.shutdown(pid)
    end

    test "returns noop logger after shutdown", %{provider: pid} do
      Otel.SDK.Logs.LoggerProvider.shutdown(pid)

      {module, _config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.API.Logs.Logger.Noop
    end
  end

  describe "force_flush/1" do
    test "returns :ok with no processors", %{provider: pid} do
      assert :ok == Otel.SDK.Logs.LoggerProvider.force_flush(pid)
    end

    test "returns error after shutdown", %{provider: pid} do
      Otel.SDK.Logs.LoggerProvider.shutdown(pid)
      assert {:error, :already_shutdown} == Otel.SDK.Logs.LoggerProvider.force_flush(pid)
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

    test "shutdown invokes processor shutdown" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      defmodule ShutdownProcessor do
        @moduledoc false
        def on_emit(_record, _ctx, _config), do: :ok

        def shutdown(config, _timeout \\ 5000) do
          send(config.test_pid, :processor_shutdown)
          :ok
        end

        def force_flush(_config, _timeout \\ 5000), do: :ok
      end

      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{ShutdownProcessor, %{test_pid: self()}}]
          }
        )

      Otel.SDK.Logs.LoggerProvider.shutdown(pid)
      assert_receive :processor_shutdown
    end

    test "force_flush invokes processor force_flush" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      defmodule FlushProcessor do
        @moduledoc false
        def on_emit(_record, _ctx, _config), do: :ok
        def shutdown(_config, _timeout \\ 5000), do: :ok

        def force_flush(config, _timeout \\ 5000) do
          send(config.test_pid, :processor_force_flush)
          :ok
        end
      end

      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{FlushProcessor, %{test_pid: self()}}]
          }
        )

      Otel.SDK.Logs.LoggerProvider.force_flush(pid)
      assert_receive :processor_force_flush
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
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{LinkableProcessor, %{}}]
          }
        )

      [entry] = Otel.SDK.Logs.LoggerProvider.config(provider_pid).processors
      assert is_pid(entry.pid)
      assert entry.callback_config == %{pid: entry.pid}

      proc_pid = entry.pid
      proc_ref = Process.monitor(proc_pid)
      Process.exit(proc_pid, :kill)
      assert_receive {:DOWN, ^proc_ref, :process, ^proc_pid, :killed}

      # Round-trip a call so the LoggerProvider has finished its own EXIT handler.
      _ = Otel.SDK.Logs.LoggerProvider.config(provider_pid)
      assert Process.alive?(provider_pid)
      assert Otel.SDK.Logs.LoggerProvider.config(provider_pid).processors == []
    end

    test "module-only processor is registered without a PID" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{ModuleOnlyProcessor, %{test_pid: self()}}]
          }
        )

      [entry] = Otel.SDK.Logs.LoggerProvider.config(provider_pid).processors
      assert entry.pid == nil
      # Callback config is the user's verbatim init_config for module-only.
      assert entry.callback_config == %{test_pid: self()}
    end
  end
end
