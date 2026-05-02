defmodule Otel.Metrics.MetricReader.PeriodicExportingTest do
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

  defp meter_config(scope_name \\ "test_lib") do
    %Otel.Metrics.Meter{config: config} =
      Otel.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: scope_name})

    config
  end

  defp restart_with_reader(opts) do
    base = %{exporter: nil, export_interval_ms: 60_000}
    config = Map.merge(base, opts)

    Otel.TestSupport.restart_with(
      metrics: [readers: [{Otel.Metrics.MetricReader.PeriodicExporting, config}]]
    )
  end

  defp record_one(scope_name \\ nil, name) do
    config = if scope_name, do: meter_config(scope_name), else: meter_config()
    counter = Otel.Metrics.Meter.create_counter(%Otel.Metrics.Meter{config: config}, name, [])
    Otel.Metrics.Meter.record(counter, 1, %{})
    config
  end

  setup do
    Otel.TestSupport.restart_with(metrics: [readers: []])
    :ok
  end

  describe "force_flush/0" do
    test "collects pending metrics, exports the batch, and calls exporter.force_flush" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})
      record_one("force_flush")

      assert :ok = Otel.Metrics.MetricReader.PeriodicExporting.force_flush()
      assert_receive {:exported, [%{name: "force_flush"}]}
      assert_receive :force_flushed
    end

    test "after shutdown → {:error, :already_shutdown}" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})
      Otel.Metrics.MetricReader.PeriodicExporting.shutdown()

      assert {:error, :already_shutdown} =
               Otel.Metrics.MetricReader.PeriodicExporting.force_flush()
    end
  end

  describe "shutdown/0" do
    test "performs a final export and calls exporter.shutdown" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})
      record_one("shutdown")

      assert :ok = Otel.Metrics.MetricReader.PeriodicExporting.shutdown()
      assert_receive {:exported, [%{name: "shutdown"}]}
      assert_receive :shut_down
    end

    test "second shutdown → {:error, :already_shutdown}" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})

      assert :ok = Otel.Metrics.MetricReader.PeriodicExporting.shutdown()

      assert {:error, :already_shutdown} =
               Otel.Metrics.MetricReader.PeriodicExporting.shutdown()
    end
  end

  describe ":collect call + :collect timer message" do
    test "GenServer.call(:collect) returns metrics; after shutdown returns {:error, :already_shutdown}" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})
      record_one("collect_counter")

      reader = Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting)
      assert {:ok, [%{name: "collect_counter"}]} = GenServer.call(reader, :collect)

      Otel.Metrics.MetricReader.PeriodicExporting.shutdown()
      assert {:error, :already_shutdown} = GenServer.call(reader, :collect)
    end

    test "stray :collect message after shutdown is absorbed (process stays alive)" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})

      reader = Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting)
      Otel.Metrics.MetricReader.PeriodicExporting.shutdown()

      send(reader, :collect)
      assert Process.alive?(reader)
    end
  end

  test "periodic timer exports on every export_interval_ms tick" do
    restart_with_reader(%{
      exporter: {TestExporter, %{test_pid: self()}},
      export_interval_ms: 50
    })

    record_one("periodic_counter")
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
    # `:compression` / `:headers` defaults) never ran and `export/2`
    # crashed on the first batch with `KeyError :compression not
    # found in: %{}`.
    test "calls exporter.init/1 once at startup; stored state replaces raw opts" do
      restart_with_reader(%{exporter: {InitTrackingExporter, %{test_pid: self(), seed: :ok}}})

      assert_receive {:exporter_init_called, %{seed: :ok}}

      reader = Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting)
      state = :sys.get_state(reader)
      assert {InitTrackingExporter, exporter_state} = state.exporter
      assert exporter_state.compression == :gzip
    end

    test ":ignore reply from exporter.init demotes exporter to nil" do
      restart_with_reader(%{exporter: {IgnoringExporter, %{}}})

      reader = Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting)
      assert :sys.get_state(reader).exporter == nil
    end
  end

  test "end-to-end: MeterProvider supervises the reader; force_flush + shutdown propagate" do
    restart_with_reader(%{
      exporter: {TestExporter, %{test_pid: self()}},
      export_interval_ms: 60_000
    })

    record_one("lib", "provider_counter")

    assert :ok = Otel.Metrics.MeterProvider.force_flush()
    assert_receive {:exported, [%{name: "provider_counter"}]}

    assert :ok = Otel.Metrics.MeterProvider.shutdown()
    assert_receive :shut_down
  end
end
