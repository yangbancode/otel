defmodule Otel.SDK.Metrics.MeterProviderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule OkReader do
    @moduledoc false
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

  defmodule FailReader do
    @moduledoc false
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

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)
  end

  defp meter_for(pid, scope_name) do
    Otel.SDK.Metrics.MeterProvider.get_meter(pid, %Otel.API.InstrumentationScope{name: scope_name})
  end

  defp views_count(pid) do
    {_, %{views: views}} = meter_for(pid, "view_count_probe")
    length(views)
  end

  setup do
    restart_sdk(metrics: [readers: []])
    %{provider: Otel.SDK.Metrics.MeterProvider}
  end

  test "registers as global MeterProvider; respects custom resource", %{provider: p} do
    assert Process.alive?(Process.whereis(p))
    assert Otel.API.Metrics.MeterProvider.get_provider() == {Otel.SDK.Metrics.MeterProvider, p}

    custom = Otel.SDK.Resource.create(%{"service.name" => "test"})
    restart_sdk(metrics: [readers: [], resource: custom])

    {_, %{resource: resource}} = meter_for(Otel.SDK.Metrics.MeterProvider, "lib")
    assert resource.attributes["service.name"] == "test"
  end

  describe "get_meter/2" do
    test "returns {SDK.Meter, config} carrying scope and SDK identity resource", %{provider: p} do
      {module, config} =
        Otel.SDK.Metrics.MeterProvider.get_meter(p, %Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0",
          schema_url: "https://example.com"
        })

      assert module == Otel.SDK.Metrics.Meter

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = config.scope

      assert %Otel.SDK.Resource{} = config.resource
      assert config.resource.attributes["telemetry.sdk.name"] == "otel"
    end

    # Spec metrics/sdk.md L?? — invalid Meter name SHOULD log a warning.
    test "empty Meter name → warns; valid name is silent", %{provider: p} do
      log = capture_log(fn -> meter_for(p, "") end)
      assert log =~ "invalid Meter name"

      silent = capture_log(fn -> meter_for(p, "ok") end)
      refute silent =~ "invalid Meter name"
    end
  end

  describe "shutdown/1 + force_flush/1" do
    test "no-reader provider: first shutdown :ok; subsequent → :already_shutdown; get_meter → Noop",
         %{provider: p} do
      assert :ok = Otel.SDK.Metrics.MeterProvider.shutdown(p)

      assert {:error, :already_shutdown} = Otel.SDK.Metrics.MeterProvider.shutdown(p)
      assert {:error, :already_shutdown} = Otel.SDK.Metrics.MeterProvider.force_flush(p)

      {Otel.API.Metrics.Meter.Noop, _} = meter_for(p, "lib")
    end

    test "lifecycle + introspection facades stay graceful when the provider isn't running" do
      Application.stop(:otel)
      refute GenServer.whereis(Otel.SDK.Metrics.MeterProvider)

      assert :ok =
               Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider, 1_000)

      assert :ok = Otel.SDK.Metrics.MeterProvider.shutdown(Otel.SDK.Metrics.MeterProvider, 1_000)

      assert %Otel.SDK.Resource{} =
               Otel.SDK.Metrics.MeterProvider.resource(Otel.SDK.Metrics.MeterProvider)

      assert %{} = Otel.SDK.Metrics.MeterProvider.config(Otel.SDK.Metrics.MeterProvider)

      assert :ok =
               Otel.SDK.Metrics.MeterProvider.add_view(
                 Otel.SDK.Metrics.MeterProvider,
                 %{name: "x"},
                 %{}
               )

      Application.ensure_all_started(:otel)
    end

    test "invokes shutdown / force_flush on every reader" do
      restart_sdk(metrics: [readers: [{OkReader, %{}}, {OkReader, %{}}]])
      assert :ok = Otel.SDK.Metrics.MeterProvider.shutdown(Otel.SDK.Metrics.MeterProvider)

      restart_sdk(metrics: [readers: [{OkReader, %{}}]])
      assert :ok = Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
    end

    test "errors from readers are collected per-reader" do
      restart_sdk(metrics: [readers: [{OkReader, %{}}, {FailReader, %{}}]])

      assert {:error, [{FailReader, :shutdown_failed}]} =
               Otel.SDK.Metrics.MeterProvider.shutdown(Otel.SDK.Metrics.MeterProvider)

      restart_sdk(metrics: [readers: [{FailReader, %{}}]])

      assert {:error, [{FailReader, :flush_failed}]} =
               Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
    end
  end

  describe "add_view/3" do
    test "registers a view; defaults criteria/config; preserves order; rejects invalid",
         %{provider: p} do
      assert :ok = Otel.SDK.Metrics.MeterProvider.add_view(p, %{type: :counter}, %{})
      assert :ok = Otel.SDK.Metrics.MeterProvider.add_view(p, %{type: :histogram}, %{})
      assert :ok = Otel.SDK.Metrics.MeterProvider.add_view(p)
      assert views_count(p) == 3

      assert {:error, _} =
               Otel.SDK.Metrics.MeterProvider.add_view(p, %{name: "*"}, %{name: "override"})

      # Invalid view didn't increment.
      assert views_count(p) == 3
    end

    test "views become visible to meters returned both before and after add_view", %{provider: p} do
      {_, before} = meter_for(p, "lib")

      :ok = Otel.SDK.Metrics.MeterProvider.add_view(p, %{name: "requests"}, %{name: "req_total"})

      {_, later} = meter_for(p, "lib")

      assert before.views == []
      assert length(later.views) == 1
    end
  end

  describe "reader crash handling" do
    test "killing a reader removes it; provider stays alive; survivor still serves" do
      restart_sdk(metrics: [readers: [{OkReader, %{}}, {OkReader, %{}}]])
      provider = Otel.SDK.Metrics.MeterProvider

      [{_, victim}, {_, survivor}] = :sys.get_state(provider).readers
      ref = Process.monitor(victim)
      Process.exit(victim, :kill)
      assert_receive {:DOWN, ^ref, :process, ^victim, :killed}

      assert Process.alive?(Process.whereis(provider))
      assert :ok = Otel.SDK.Metrics.MeterProvider.force_flush(provider)
      assert [{_, ^survivor}] = :sys.get_state(provider).readers
    end

    test "ignores EXIT from unmanaged processes; ignores late EXIT after shutdown",
         %{provider: p} do
      send(Process.whereis(p), {:EXIT, self(), :unrelated})
      assert is_map(:sys.get_state(p))

      :ok = Otel.SDK.Metrics.MeterProvider.shutdown(p)
      send(Process.whereis(p), {:EXIT, self(), :late})
      assert match?(%{shut_down: true}, :sys.get_state(p))
    end
  end

  test "resource/1 + config/1 return the boot-time provider state", %{provider: p} do
    assert %Otel.SDK.Resource{} = Otel.SDK.Metrics.MeterProvider.resource(p)

    config = Otel.SDK.Metrics.MeterProvider.config(p)
    for field <- [:readers, :views, :resource], do: assert(Map.has_key?(config, field))
  end
end
