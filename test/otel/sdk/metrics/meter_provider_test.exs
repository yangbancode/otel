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
    restart_sdk(metrics: [exporter: :none])
    %{provider: Otel.SDK.Metrics.MeterProvider}
  end

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

  describe "start_link/1" do
    test "starts with default config", %{provider: provider} do
      assert Process.alive?(Process.whereis(provider))
    end

    test "registers as global provider on start", %{provider: provider} do
      assert Otel.API.Metrics.MeterProvider.get_provider() ==
               {Otel.SDK.Metrics.MeterProvider, provider}
    end

    test "starts with custom config" do
      custom_resource = Otel.SDK.Resource.create(%{"service.name" => "test"})
      restart_sdk(metrics: [exporter: :none, resource: custom_resource])

      {_module, %{resource: resource}} =
        Otel.SDK.Metrics.MeterProvider.get_meter(
          Otel.SDK.Metrics.MeterProvider,
          %Otel.API.InstrumentationScope{name: "lib"}
        )

      assert resource.attributes["service.name"] == "test"
    end
  end

  describe "get_meter/2,3,4" do
    test "returns SDK meter tuple", %{provider: pid} do
      {module, meter_config} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.SDK.Metrics.Meter
      assert %{scope: _, resource: _} = meter_config
    end

    test "meter includes instrumentation scope", %{provider: pid} do
      {_module, %{scope: scope}} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{
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

    test "meter includes resource", %{provider: pid} do
      {_module, %{resource: resource}} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert %Otel.SDK.Resource{} = resource
      assert resource.attributes["telemetry.sdk.name"] == "otel"
    end

    test "logs a warning for empty Meter name (spec MUST/SHOULD)", %{provider: pid} do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: ""})
        end)

      assert log =~ "invalid Meter name"
    end

    test "no warning for a valid Meter name", %{provider: pid} do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{
            name: "my_lib"
          })
        end)

      refute log =~ "invalid Meter name"
    end
  end

  describe "shutdown/1" do
    test "returns :ok with no readers", %{provider: pid} do
      assert Otel.SDK.Metrics.MeterProvider.shutdown(pid) == :ok
    end

    test "invokes shutdown on all readers" do
      restart_sdk(
        metrics: [
          readers: [
            {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}},
            {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}}
          ]
        ]
      )

      assert Otel.SDK.Metrics.MeterProvider.shutdown(Otel.SDK.Metrics.MeterProvider) == :ok
    end

    test "collects errors from failing readers" do
      restart_sdk(
        metrics: [
          readers: [
            {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}},
            {Otel.SDK.Metrics.MeterProviderTest.FailReader, %{}}
          ]
        ]
      )

      assert {:error, [{Otel.SDK.Metrics.MeterProviderTest.FailReader, :shutdown_failed}]} =
               Otel.SDK.Metrics.MeterProvider.shutdown(Otel.SDK.Metrics.MeterProvider)
    end

    test "returns noop meter after shutdown", %{provider: pid} do
      Otel.SDK.Metrics.MeterProvider.shutdown(pid)

      {module, _} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{
          name: "my_lib"
        })

      assert module == Otel.API.Metrics.Meter.Noop
    end

    test "second shutdown returns error", %{provider: pid} do
      assert Otel.SDK.Metrics.MeterProvider.shutdown(pid) == :ok
      assert Otel.SDK.Metrics.MeterProvider.shutdown(pid) == {:error, :already_shutdown}
    end
  end

  describe "add_view/3" do
    test "registers a view", %{provider: pid} do
      assert :ok ==
               Otel.SDK.Metrics.MeterProvider.add_view(pid, %{name: "requests"}, %{
                 name: "req_total"
               })

      assert_view_count(pid, 1)
    end

    test "rejects invalid view", %{provider: pid} do
      assert {:error, _} =
               Otel.SDK.Metrics.MeterProvider.add_view(pid, %{name: "*"}, %{name: "override"})

      assert_view_count(pid, 0)
    end

    test "views apply to already returned meters", %{provider: pid} do
      {_module, config_before} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: "lib"})

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(pid, %{name: "requests"}, %{name: "req_total"})

      {_module, config_after} =
        Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: "lib"})

      assert length(config_after.views) == 1
      assert config_before.views == []
    end

    test "multiple views preserved in order", %{provider: pid} do
      :ok = Otel.SDK.Metrics.MeterProvider.add_view(pid, %{type: :counter}, %{})
      :ok = Otel.SDK.Metrics.MeterProvider.add_view(pid, %{type: :histogram}, %{})
      assert_view_count(pid, 2)
    end

    test "registers view with default criteria and config", %{provider: pid} do
      assert :ok == Otel.SDK.Metrics.MeterProvider.add_view(pid)
      assert_view_count(pid, 1)
    end
  end

  describe "force_flush/1" do
    test "returns :ok with no readers", %{provider: pid} do
      assert Otel.SDK.Metrics.MeterProvider.force_flush(pid) == :ok
    end

    test "invokes force_flush on all readers" do
      restart_sdk(metrics: [readers: [{Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}}]])

      assert Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider) == :ok
    end

    test "collects errors from failing readers" do
      restart_sdk(metrics: [readers: [{Otel.SDK.Metrics.MeterProviderTest.FailReader, %{}}]])

      assert {:error, [{Otel.SDK.Metrics.MeterProviderTest.FailReader, :flush_failed}]} =
               Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
    end

    test "returns error after shutdown", %{provider: pid} do
      Otel.SDK.Metrics.MeterProvider.shutdown(pid)
      assert Otel.SDK.Metrics.MeterProvider.force_flush(pid) == {:error, :already_shutdown}
    end
  end

  describe "reader crash handling" do
    test "removes a crashed reader and keeps serving the rest" do
      restart_sdk(
        metrics: [
          readers: [
            {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}},
            {Otel.SDK.Metrics.MeterProviderTest.OkReader, %{}}
          ]
        ]
      )

      provider = Otel.SDK.Metrics.MeterProvider
      [{_, victim}, {_, survivor}] = :sys.get_state(provider).readers
      ref = Process.monitor(victim)
      Process.exit(victim, :kill)
      assert_receive {:DOWN, ^ref, :process, ^victim, :killed}

      # Provider stays alive; survivor keeps serving force_flush
      # (the dead reader has been dropped from the active list).
      assert Process.alive?(Process.whereis(provider))
      assert :ok = Otel.SDK.Metrics.MeterProvider.force_flush(provider)
      assert [{_, ^survivor}] = :sys.get_state(provider).readers
    end

    test "ignores EXIT from unmanaged process", %{provider: provider} do
      send(Process.whereis(provider), {:EXIT, self(), :unrelated})
      # Round-trip a call to force the EXIT to be processed.
      assert is_map(:sys.get_state(provider))
    end

    test "ignores late EXIT after shutdown", %{provider: provider} do
      :ok = Otel.SDK.Metrics.MeterProvider.shutdown(provider)
      send(Process.whereis(provider), {:EXIT, self(), :late})
      assert match?(%{shut_down: true}, :sys.get_state(provider))
    end
  end

  # The provider's view list is observable through the meter
  # config returned by `get_meter/2` — the meter sees the
  describe "introspection" do
    test "resource/1 returns the configured resource", %{provider: pid} do
      assert %Otel.SDK.Resource{} = Otel.SDK.Metrics.MeterProvider.resource(pid)
    end

    test "config/1 returns the runtime config snapshot", %{provider: pid} do
      config = Otel.SDK.Metrics.MeterProvider.config(pid)
      assert is_map(config)
      assert Map.has_key?(config, :readers)
      assert Map.has_key?(config, :views)
      assert Map.has_key?(config, :resource)
    end
  end

  # view list at every dispatch.
  defp assert_view_count(provider_pid, expected_count) do
    {_module, %{views: views}} =
      Otel.SDK.Metrics.MeterProvider.get_meter(provider_pid, %Otel.API.InstrumentationScope{
        name: "view_count_probe"
      })

    assert length(views) == expected_count
  end
end
