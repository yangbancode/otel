defmodule Otel.SDK.Metrics.MetricReader.PeriodicExportingTest do
  use ExUnit.Case, async: false

  defmodule TestExporter do
    @moduledoc false

    def init(opts), do: {:ok, opts}

    def export(batch, %{test_pid: pid}) do
      send(pid, {:exported, batch})
      :ok
    end

    def force_flush(%{test_pid: pid}) do
      send(pid, :force_flushed)
      :ok
    end

    def shutdown(%{test_pid: pid}) do
      send(pid, :shut_down)
      :ok
    end
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

  defp meter_config do
    {_, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.API.InstrumentationScope{name: "test_lib"}
      )

    config
  end

  defp start_reader(opts) do
    base = %{meter_config: meter_config(), exporter: nil, export_interval_ms: 60_000}
    # `start_link` links the reader to the test process; ExUnit
    # exits the test process with :shutdown before on_exit fires,
    # so the link cascade tears the reader down deterministically
    # without needing a manual `GenServer.stop` (which races
    # against the cascade and was the source of intermittent
    # `:noproc` failures on CI).
    {:ok, pid} = Otel.SDK.Metrics.MetricReader.PeriodicExporting.start_link(Map.merge(base, opts))
    pid
  end

  defp record_one(scope_name \\ nil, name) do
    config = if scope_name, do: meter_config_for(scope_name), else: meter_config()
    counter = Otel.SDK.Metrics.Meter.create_counter({Otel.SDK.Metrics.Meter, config}, name, [])
    Otel.SDK.Metrics.Meter.record(counter, 1, %{})
    config
  end

  defp meter_config_for(scope_name) do
    {_, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.API.InstrumentationScope{name: scope_name}
      )

    config
  end

  setup do
    restart_sdk(metrics: [readers: []])
    :ok
  end

  describe "force_flush/1" do
    test "collects pending metrics, exports the batch, and calls exporter.force_flush" do
      record_one("force_flush")

      reader =
        start_reader(%{exporter: {TestExporter, %{test_pid: self()}}})

      assert :ok = Otel.SDK.Metrics.MetricReader.PeriodicExporting.force_flush(reader)
      assert_receive {:exported, [%{name: "force_flush"}]}
      assert_receive :force_flushed
    end

    test "after shutdown → {:error, :already_shutdown}" do
      reader = start_reader(%{})
      Otel.SDK.Metrics.MetricReader.PeriodicExporting.shutdown(reader)

      assert {:error, :already_shutdown} =
               Otel.SDK.Metrics.MetricReader.PeriodicExporting.force_flush(reader)
    end
  end

  describe "shutdown/1" do
    test "performs a final export and calls exporter.shutdown" do
      record_one("shutdown")

      reader =
        start_reader(%{exporter: {TestExporter, %{test_pid: self()}}})

      assert :ok = Otel.SDK.Metrics.MetricReader.PeriodicExporting.shutdown(reader)
      assert_receive {:exported, [%{name: "shutdown"}]}
      assert_receive :shut_down
    end

    test "second shutdown → {:error, :already_shutdown}" do
      reader = start_reader(%{})
      assert :ok = Otel.SDK.Metrics.MetricReader.PeriodicExporting.shutdown(reader)

      assert {:error, :already_shutdown} =
               Otel.SDK.Metrics.MetricReader.PeriodicExporting.shutdown(reader)
    end
  end

  describe ":collect call + :collect timer message" do
    test "GenServer.call(:collect) returns metrics; after shutdown returns {:error, :already_shutdown}" do
      record_one("collect_counter")
      reader = start_reader(%{})

      assert {:ok, [%{name: "collect_counter"}]} = GenServer.call(reader, :collect)

      Otel.SDK.Metrics.MetricReader.PeriodicExporting.shutdown(reader)
      assert {:error, :already_shutdown} = GenServer.call(reader, :collect)
    end

    test "stray :collect message after shutdown is absorbed (process stays alive)" do
      reader = start_reader(%{})
      Otel.SDK.Metrics.MetricReader.PeriodicExporting.shutdown(reader)

      send(reader, :collect)
      assert Process.alive?(reader)
    end
  end

  test "periodic timer exports on every export_interval_ms tick" do
    record_one("periodic_counter")

    _ =
      start_reader(%{
        exporter: {TestExporter, %{test_pid: self()}},
        export_interval_ms: 50
      })

    assert_receive {:exported, _}, 200
  end

  describe "init/1 exporter initialization" do
    defmodule InitTrackingExporter do
      @moduledoc false
      def init(%{test_pid: pid} = opts) do
        send(pid, {:exporter_init_called, opts})
        {:ok, Map.put(opts, :compression, :gzip)}
      end

      def export(_batch, _state), do: :ok
      def force_flush(_state), do: :ok
      def shutdown(_state), do: :ok
    end

    defmodule IgnoringExporter do
      @moduledoc false
      def init(_opts), do: :ignore
      def export(_, _), do: :ok
      def force_flush(_), do: :ok
      def shutdown(_), do: :ok
    end

    # Regression: PeriodicExporting used to store `config.exporter`
    # verbatim, so the exporter's `init/1` (where OTLP HTTP populates
    # `:compression` / `:headers` / `:retry_opts` defaults) never
    # ran and `export/2` crashed on the first batch with `KeyError
    # :compression not found in: %{}`.
    test "calls exporter.init/1 once at startup; stored state replaces raw opts" do
      reader =
        start_reader(%{
          exporter: {InitTrackingExporter, %{test_pid: self(), seed: :ok}}
        })

      assert_receive {:exporter_init_called, %{seed: :ok}}

      state = :sys.get_state(reader)
      assert {InitTrackingExporter, exporter_state} = state.exporter
      assert exporter_state.compression == :gzip
    end

    test ":ignore reply from exporter.init demotes exporter to nil" do
      reader = start_reader(%{exporter: {IgnoringExporter, %{}}})
      assert :sys.get_state(reader).exporter == nil
    end
  end

  test "end-to-end: MeterProvider supervises the reader; force_flush + shutdown propagate" do
    restart_sdk(
      metrics: [
        readers: [
          {Otel.SDK.Metrics.MetricReader.PeriodicExporting,
           %{exporter: {TestExporter, %{test_pid: self()}}, export_interval_ms: 60_000}}
        ]
      ]
    )

    record_one("lib", "provider_counter")

    assert :ok = Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
    assert_receive {:exported, [%{name: "provider_counter"}]}

    assert :ok = Otel.SDK.Metrics.MeterProvider.shutdown(Otel.SDK.Metrics.MeterProvider)
    assert_receive :shut_down
  end
end
