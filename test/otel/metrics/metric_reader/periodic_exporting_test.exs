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

  defp meter_config do
    %Otel.Metrics.Meter{config: config} = Otel.Metrics.MeterProvider.get_meter()
    config
  end

  defp restart_with_reader(opts) do
    base = %{exporter: nil, export_interval_ms: 60_000}
    config = Map.merge(base, opts)

    Otel.TestSupport.restart_with(
      metrics: [readers: [{Otel.Metrics.MetricReader.PeriodicExporting, config}]]
    )
  end

  defp record_one(name) do
    config = meter_config()
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
  end

  describe "supervisor-driven termination" do
    test "terminate/2 performs a final export and calls exporter.shutdown" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})
      record_one("terminate")

      reader = Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting)
      Process.unlink(reader)
      ref = Process.monitor(reader)
      Process.exit(reader, :shutdown)
      assert_receive {:DOWN, ^ref, :process, ^reader, _reason}

      assert_receive {:exported, [%{name: "terminate"}]}
      assert_receive :shut_down
    end
  end

  describe ":collect call" do
    test "GenServer.call(:collect) returns metrics" do
      restart_with_reader(%{exporter: {TestExporter, %{test_pid: self()}}})
      record_one("collect_counter")

      reader = Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting)
      assert {:ok, [%{name: "collect_counter"}]} = GenServer.call(reader, :collect)
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

  test "end-to-end: supervised reader force_flush exports; supervisor termination calls exporter.shutdown" do
    restart_with_reader(%{
      exporter: {TestExporter, %{test_pid: self()}},
      export_interval_ms: 60_000
    })

    record_one("provider_counter")

    assert :ok = Otel.Metrics.MetricReader.PeriodicExporting.force_flush()
    assert_receive {:exported, [%{name: "provider_counter"}]}

    # Graceful shutdown via `:shutdown` exit signal so terminate/2
    # runs (TestSupport.stop_all uses `:kill`, which is brutal and
    # skips terminate). The reader is already orphan from the
    # test process, so no unlink needed.
    reader = Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting)
    ref = Process.monitor(reader)
    Process.exit(reader, :shutdown)
    assert_receive {:DOWN, ^ref, :process, ^reader, _reason}

    assert_receive :shut_down
  end
end
