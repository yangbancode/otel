defmodule Otel.SDK.Metrics.MeterProviderTest.OkReader do
  use GenServer
  def start_link(config), do: GenServer.start_link(__MODULE__, config)
  def shutdown(pid), do: GenServer.call(pid, :shutdown)
  def force_flush(pid), do: GenServer.call(pid, :force_flush)

  @impl true
  def init(config), do: {:ok, config}
  @impl true
  def handle_call(:shutdown, _from, state), do: {:reply, :ok, state}
  def handle_call(:force_flush, _from, state), do: {:reply, :ok, state}
end

defmodule Otel.SDK.Metrics.MeterProviderTest.FailReader do
  use GenServer
  def start_link(config), do: GenServer.start_link(__MODULE__, config)
  def shutdown(pid), do: GenServer.call(pid, :shutdown)
  def force_flush(pid), do: GenServer.call(pid, :force_flush)

  @impl true
  def init(config), do: {:ok, config}
  @impl true
  def handle_call(:shutdown, _from, state), do: {:reply, {:error, :shutdown_failed}, state}
  def handle_call(:force_flush, _from, state), do: {:reply, {:error, :flush_failed}, state}
end

defmodule Otel.SDK.Metrics.MeterProviderTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    %{provider: pid}
  end

  describe "start_link/1" do
    test "starts with default config" do
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})
      assert Process.alive?(pid)
    end

    test "registers as global provider on start" do
      {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

      assert Otel.API.Metrics.MeterProvider.get_provider() ==
               {Otel.SDK.Metrics.MeterProvider, pid}
    end

    test "starts with custom config" do
      custom_resource = Otel.SDK.Resource.create(%{"service.name" => "test"})

      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(config: %{resource: custom_resource})

      resource = Otel.SDK.Metrics.MeterProvider.resource(pid)
      assert resource.attributes["service.name"] == "test"
    end
  end

  describe "get_meter/2,3,4" do
    test "returns SDK meter tuple", %{provider: pid} do
      {module, meter_config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "my_lib")
      assert module == Otel.SDK.Metrics.Meter
      assert %{scope: _, resource: _} = meter_config
    end

    test "meter includes instrumentation scope", %{provider: pid} do
      {_module, %{scope: scope}} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, "my_lib", "1.0.0", "https://example.com")

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = scope
    end

    test "meter includes resource", %{provider: pid} do
      {_module, %{resource: resource}} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, "my_lib")

      assert %Otel.SDK.Resource{} = resource
      assert resource.attributes["telemetry.sdk.name"] == "otel"
    end
  end

  describe "config/1" do
    test "returns merged config with defaults", %{provider: pid} do
      config = Otel.SDK.Metrics.MeterProvider.config(pid)

      assert config.views == []
      assert config.readers == []
      assert %Otel.SDK.Resource{} = config.resource
    end

    test "custom config overrides defaults" do
      custom_resource = Otel.SDK.Resource.create(%{"service.name" => "custom"})

      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(config: %{resource: custom_resource})

      config = Otel.SDK.Metrics.MeterProvider.config(pid)
      assert config.resource.attributes["service.name"] == "custom"
      assert config.views == []
    end
  end

  describe "resource/1" do
    test "returns SDK default resource", %{provider: pid} do
      resource = Otel.SDK.Metrics.MeterProvider.resource(pid)
      assert %Otel.SDK.Resource{} = resource
      assert resource.attributes["telemetry.sdk.name"] == "otel"
      assert resource.attributes["telemetry.sdk.language"] == "elixir"
    end
  end

  describe "shutdown/1" do
    test "returns :ok with no readers", %{provider: pid} do
      assert Otel.SDK.Metrics.MeterProvider.shutdown(pid) == :ok
    end

    test "invokes shutdown on all readers" do
      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(
          config: %{
            readers: [
              {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}},
              {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}}
            ]
          }
        )

      assert Otel.SDK.Metrics.MeterProvider.shutdown(pid) == :ok
    end

    test "collects errors from failing readers" do
      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(
          config: %{
            readers: [
              {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}},
              {Otel.SDK.Metrics.MeterProviderTest.FailReader, %{}}
            ]
          }
        )

      assert {:error, [{Otel.SDK.Metrics.MeterProviderTest.FailReader, :shutdown_failed}]} =
               Otel.SDK.Metrics.MeterProvider.shutdown(pid)
    end

    test "returns noop meter after shutdown", %{provider: pid} do
      Otel.SDK.Metrics.MeterProvider.shutdown(pid)
      {module, _} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "my_lib")
      assert module == Otel.API.Metrics.Meter.Noop
    end

    test "second shutdown returns error", %{provider: pid} do
      assert Otel.SDK.Metrics.MeterProvider.shutdown(pid) == :ok
      assert Otel.SDK.Metrics.MeterProvider.shutdown(pid) == {:error, :already_shut_down}
    end
  end

  describe "add_view/3" do
    test "registers a view", %{provider: pid} do
      assert :ok ==
               Otel.SDK.Metrics.MeterProvider.add_view(pid, %{name: "requests"}, %{
                 name: "req_total"
               })

      config = Otel.SDK.Metrics.MeterProvider.config(pid)
      assert length(config.views) == 1
    end

    test "rejects invalid view", %{provider: pid} do
      assert {:error, _} =
               Otel.SDK.Metrics.MeterProvider.add_view(pid, %{name: "*"}, %{name: "override"})

      config = Otel.SDK.Metrics.MeterProvider.config(pid)
      assert config.views == []
    end

    test "views apply to already returned meters", %{provider: pid} do
      {_module, config_before} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(pid, %{name: "requests"}, %{name: "req_total"})

      {_module, config_after} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "lib")
      assert length(config_after.views) == 1
      assert config_before.views == []
    end

    test "multiple views preserved in order", %{provider: pid} do
      :ok = Otel.SDK.Metrics.MeterProvider.add_view(pid, %{type: :counter}, %{})
      :ok = Otel.SDK.Metrics.MeterProvider.add_view(pid, %{type: :histogram}, %{})
      config = Otel.SDK.Metrics.MeterProvider.config(pid)
      assert length(config.views) == 2
    end

    test "registers view with default criteria and config", %{provider: pid} do
      assert :ok == Otel.SDK.Metrics.MeterProvider.add_view(pid)
      config = Otel.SDK.Metrics.MeterProvider.config(pid)
      assert length(config.views) == 1
    end
  end

  describe "force_flush/1" do
    test "returns :ok with no readers", %{provider: pid} do
      assert Otel.SDK.Metrics.MeterProvider.force_flush(pid) == :ok
    end

    test "invokes force_flush on all readers" do
      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(
          config: %{
            readers: [{Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}}]
          }
        )

      assert Otel.SDK.Metrics.MeterProvider.force_flush(pid) == :ok
    end

    test "collects errors from failing readers" do
      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(
          config: %{
            readers: [{Otel.SDK.Metrics.MeterProviderTest.FailReader, %{}}]
          }
        )

      assert {:error, [{Otel.SDK.Metrics.MeterProviderTest.FailReader, :flush_failed}]} =
               Otel.SDK.Metrics.MeterProvider.force_flush(pid)
    end

    test "returns error after shutdown", %{provider: pid} do
      Otel.SDK.Metrics.MeterProvider.shutdown(pid)
      assert Otel.SDK.Metrics.MeterProvider.force_flush(pid) == {:error, :shut_down}
    end
  end
end
