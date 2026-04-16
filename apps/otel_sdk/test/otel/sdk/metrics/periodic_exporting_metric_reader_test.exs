defmodule Otel.SDK.Metrics.PeriodicExportingMetricReaderTest.TestExporter do
  def export(batch, config) do
    send(config.test_pid, {:exported, batch})
    :ok
  end

  def force_flush(config) do
    send(config.test_pid, :force_flushed)
    :ok
  end

  def shutdown(config) do
    send(config.test_pid, :shut_down)
    :ok
  end
end

defmodule Otel.SDK.Metrics.PeriodicExportingMetricReaderTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, provider} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})
    {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(provider, "test_lib")

    on_exit(fn ->
      if Process.alive?(provider), do: GenServer.stop(provider)
    end)

    %{config: config, provider: provider}
  end

  describe "start_link/1" do
    test "starts reader process", %{config: config} do
      {:ok, pid} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: nil,
          export_interval_ms: 60_000
        })

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "force_flush/1" do
    test "collects and exports metrics", %{config: config} do
      meter = {Otel.SDK.Metrics.Meter, config}
      Otel.SDK.Metrics.Meter.create_counter(meter, "flush_counter", [])
      Otel.SDK.Metrics.Meter.record(meter, "flush_counter", 10, %{})

      exporter =
        {Otel.SDK.Metrics.PeriodicExportingMetricReaderTest.TestExporter, %{test_pid: self()}}

      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: exporter,
          export_interval_ms: 60_000
        })

      assert :ok == Otel.SDK.Metrics.PeriodicExportingMetricReader.force_flush(reader)
      assert_receive {:exported, batch}
      assert length(batch) == 1
      assert hd(batch).name == "flush_counter"
      assert_receive :force_flushed
      GenServer.stop(reader)
    end

    test "returns error after shutdown", %{config: config} do
      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: nil,
          export_interval_ms: 60_000
        })

      Otel.SDK.Metrics.PeriodicExportingMetricReader.shutdown(reader)

      assert {:error, :shut_down} ==
               Otel.SDK.Metrics.PeriodicExportingMetricReader.force_flush(reader)

      GenServer.stop(reader)
    end
  end

  describe "shutdown/1" do
    test "performs final export and shuts down exporter", %{config: config} do
      meter = {Otel.SDK.Metrics.Meter, config}
      Otel.SDK.Metrics.Meter.create_counter(meter, "shutdown_counter", [])
      Otel.SDK.Metrics.Meter.record(meter, "shutdown_counter", 5, %{})

      exporter =
        {Otel.SDK.Metrics.PeriodicExportingMetricReaderTest.TestExporter, %{test_pid: self()}}

      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: exporter,
          export_interval_ms: 60_000
        })

      assert :ok == Otel.SDK.Metrics.PeriodicExportingMetricReader.shutdown(reader)
      assert_receive {:exported, _batch}
      assert_receive :shut_down
      GenServer.stop(reader)
    end

    test "second shutdown returns error", %{config: config} do
      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: nil,
          export_interval_ms: 60_000
        })

      assert :ok == Otel.SDK.Metrics.PeriodicExportingMetricReader.shutdown(reader)

      assert {:error, :already_shut_down} ==
               Otel.SDK.Metrics.PeriodicExportingMetricReader.shutdown(reader)

      GenServer.stop(reader)
    end
  end

  describe "collect call" do
    test "returns metrics via GenServer call", %{config: config} do
      meter = {Otel.SDK.Metrics.Meter, config}
      Otel.SDK.Metrics.Meter.create_counter(meter, "collect_counter", [])
      Otel.SDK.Metrics.Meter.record(meter, "collect_counter", 7, %{})

      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: nil,
          export_interval_ms: 60_000
        })

      assert {:ok, metrics} = GenServer.call(reader, :collect)
      assert [metric] = metrics
      assert metric.name == "collect_counter"
      GenServer.stop(reader)
    end

    test "returns error after shutdown", %{config: config} do
      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: nil,
          export_interval_ms: 60_000
        })

      Otel.SDK.Metrics.PeriodicExportingMetricReader.shutdown(reader)
      assert {:error, :shut_down} = GenServer.call(reader, :collect)
      GenServer.stop(reader)
    end
  end

  describe "timer after shutdown" do
    test "collect timer is no-op after shutdown", %{config: config} do
      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: nil,
          export_interval_ms: 60_000
        })

      Otel.SDK.Metrics.PeriodicExportingMetricReader.shutdown(reader)
      send(reader, :collect)
      assert Process.alive?(reader)
      GenServer.stop(reader)
    end
  end

  describe "periodic collection" do
    test "exports on interval", %{config: config} do
      meter = {Otel.SDK.Metrics.Meter, config}
      Otel.SDK.Metrics.Meter.create_counter(meter, "periodic_counter", [])
      Otel.SDK.Metrics.Meter.record(meter, "periodic_counter", 1, %{})

      exporter =
        {Otel.SDK.Metrics.PeriodicExportingMetricReaderTest.TestExporter, %{test_pid: self()}}

      {:ok, reader} =
        Otel.SDK.Metrics.PeriodicExportingMetricReader.start_link(%{
          meter_config: config,
          exporter: exporter,
          export_interval_ms: 50
        })

      assert_receive {:exported, _batch}, 200
      GenServer.stop(reader)
    end
  end

  describe "integration with MeterProvider" do
    test "provider starts and manages reader" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      exporter =
        {Otel.SDK.Metrics.PeriodicExportingMetricReaderTest.TestExporter, %{test_pid: self()}}

      {:ok, provider} =
        Otel.SDK.Metrics.MeterProvider.start_link(
          config: %{
            readers: [
              {Otel.SDK.Metrics.PeriodicExportingMetricReader,
               %{exporter: exporter, export_interval_ms: 60_000}}
            ]
          }
        )

      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(provider, "lib")
      meter = {Otel.SDK.Metrics.Meter, config}
      Otel.SDK.Metrics.Meter.create_counter(meter, "provider_counter", [])
      Otel.SDK.Metrics.Meter.record(meter, "provider_counter", 1, %{})

      assert :ok == Otel.SDK.Metrics.MeterProvider.force_flush(provider)
      assert_receive {:exported, batch}
      assert length(batch) == 1

      assert :ok == Otel.SDK.Metrics.MeterProvider.shutdown(provider)
      assert_receive :shut_down
    end
  end
end
