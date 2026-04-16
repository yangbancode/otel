defmodule Otel.SDK.Metrics.TemporalityTest.DeltaReader do
  use GenServer

  @behaviour Otel.SDK.Metrics.MetricReader

  @impl Otel.SDK.Metrics.MetricReader
  def start_link(config), do: GenServer.start_link(__MODULE__, config)

  @impl Otel.SDK.Metrics.MetricReader
  def shutdown(pid), do: GenServer.call(pid, :shutdown)

  @impl Otel.SDK.Metrics.MetricReader
  def force_flush(pid), do: GenServer.call(pid, :force_flush)

  def collect(pid), do: GenServer.call(pid, :collect)

  @impl GenServer
  def init(config), do: {:ok, config}

  @impl GenServer
  def handle_call(:collect, _from, state) do
    metrics = Otel.SDK.Metrics.MetricReader.collect(state.meter_config)
    {:reply, {:ok, metrics}, state}
  end

  def handle_call(:shutdown, _from, state), do: {:reply, :ok, state}
  def handle_call(:force_flush, _from, state), do: {:reply, :ok, state}
end

defmodule Otel.SDK.Metrics.TemporalityTest do
  use ExUnit.Case

  @delta_temporality_mapping %{
    counter: :delta,
    updown_counter: :delta,
    histogram: :delta,
    gauge: :cumulative,
    observable_counter: :delta,
    observable_gauge: :cumulative,
    observable_updown_counter: :delta
  }

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  defp setup_default_provider do
    {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})
    {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "test_lib")
    meter = {Otel.SDK.Metrics.Meter, config}
    %{meter: meter, config: config, provider: pid}
  end

  defp setup_delta_provider do
    {:ok, pid} =
      Otel.SDK.Metrics.MeterProvider.start_link(
        config: %{
          readers: [
            {Otel.SDK.Metrics.TemporalityTest.DeltaReader,
             %{temporality_mapping: @delta_temporality_mapping}}
          ]
        }
      )

    config = Otel.SDK.Metrics.MeterProvider.config(pid)
    [{_mod, reader_pid}] = config.readers
    {_mod, meter_config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "test_lib")
    meter = {Otel.SDK.Metrics.Meter, meter_config}
    %{meter: meter, reader_pid: reader_pid, provider: pid}
  end

  describe "default cumulative temporality" do
    test "counter collects cumulative by default" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "requests", [])
      Otel.SDK.Metrics.Meter.record(meter, "requests", 5, %{})
      Otel.SDK.Metrics.Meter.record(meter, "requests", 3, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.temporality == :cumulative
      assert metric.is_monotonic == true
      assert [dp] = metric.datapoints
      assert dp.value == 8

      Otel.SDK.Metrics.Meter.record(meter, "requests", 2, %{})
      [metric2] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp2] = metric2.datapoints
      assert dp2.value == 10
      assert dp2.start_time == dp.start_time

      GenServer.stop(pid)
    end

    test "updown_counter is not monotonic" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      Otel.SDK.Metrics.Meter.create_updown_counter(meter, "connections", [])
      Otel.SDK.Metrics.Meter.record(meter, "connections", 5, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.temporality == :cumulative
      assert metric.is_monotonic == false

      GenServer.stop(pid)
    end

    test "gauge has no temporality" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      Otel.SDK.Metrics.Meter.create_gauge(meter, "temperature", [])
      Otel.SDK.Metrics.Meter.record(meter, "temperature", 22, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.temporality == nil
      assert metric.is_monotonic == nil

      GenServer.stop(pid)
    end

    test "histogram collects cumulative by default" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", [])
      Otel.SDK.Metrics.Meter.record(meter, "latency", 50, %{})
      Otel.SDK.Metrics.Meter.record(meter, "latency", 150, %{})

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.temporality == :cumulative
      assert metric.is_monotonic == false

      Otel.SDK.Metrics.Meter.record(meter, "latency", 200, %{})
      [metric2] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp2] = metric2.datapoints
      assert dp2.value.count == 3
      assert dp2.value.sum == 400

      GenServer.stop(pid)
    end

    test "observable_counter has cumulative temporality and is monotonic" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      cb = fn _args -> [{100, %{}}] end
      Otel.SDK.Metrics.Meter.create_observable_counter(meter, "bytes", cb, nil, [])

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.temporality == :cumulative
      assert metric.is_monotonic == true

      GenServer.stop(pid)
    end

    test "observable_gauge has no temporality" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      cb = fn _args -> [{42, %{}}] end
      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.temporality == nil
      assert metric.is_monotonic == nil

      GenServer.stop(pid)
    end

    test "observable_updown_counter is not monotonic" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      cb = fn _args -> [{10, %{}}] end

      Otel.SDK.Metrics.Meter.create_observable_updown_counter(
        meter,
        "queue_size",
        cb,
        nil,
        []
      )

      [metric] = Otel.SDK.Metrics.MetricReader.collect(config)
      assert metric.temporality == :cumulative
      assert metric.is_monotonic == false

      GenServer.stop(pid)
    end

    test "cumulative start_time is stable across collections" do
      %{meter: meter, config: config, provider: pid} = setup_default_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "stable", [])
      Otel.SDK.Metrics.Meter.record(meter, "stable", 1, %{})

      [m1] = Otel.SDK.Metrics.MetricReader.collect(config)
      start1 = hd(m1.datapoints).start_time

      Otel.SDK.Metrics.Meter.record(meter, "stable", 1, %{})
      [m2] = Otel.SDK.Metrics.MetricReader.collect(config)
      start2 = hd(m2.datapoints).start_time

      assert start1 == start2

      GenServer.stop(pid)
    end
  end

  describe "delta temporality with reader" do
    test "counter sum resets between collections" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "delta_counter", [])
      Otel.SDK.Metrics.Meter.record(meter, "delta_counter", 5, %{})
      Otel.SDK.Metrics.Meter.record(meter, "delta_counter", 3, %{})

      {:ok, [metric]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert metric.temporality == :delta
      assert metric.is_monotonic == true
      [dp1] = metric.datapoints
      assert dp1.value == 8

      Otel.SDK.Metrics.Meter.record(meter, "delta_counter", 2, %{})

      {:ok, [metric2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      [dp2] = metric2.datapoints
      assert dp2.value == 2
      assert dp2.start_time >= dp1.time

      GenServer.stop(pid)
    end

    test "delta counter with no new measurements returns empty" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "empty_delta", [])
      Otel.SDK.Metrics.Meter.record(meter, "empty_delta", 5, %{})

      {:ok, [_metric]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      {:ok, metrics} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert metrics == []

      GenServer.stop(pid)
    end

    test "delta histogram resets between collections" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_histogram(meter, "delta_latency", [])
      Otel.SDK.Metrics.Meter.record(meter, "delta_latency", 50, %{})
      Otel.SDK.Metrics.Meter.record(meter, "delta_latency", 150, %{})

      {:ok, [metric1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert metric1.temporality == :delta
      [dp1] = metric1.datapoints
      assert dp1.value.count == 2
      assert dp1.value.sum == 200
      assert dp1.value.min == 50
      assert dp1.value.max == 150

      Otel.SDK.Metrics.Meter.record(meter, "delta_latency", 300, %{})

      {:ok, [metric2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      [dp2] = metric2.datapoints
      assert dp2.value.count == 1
      assert dp2.value.sum == 300
      assert dp2.value.min == 300
      assert dp2.value.max == 300

      GenServer.stop(pid)
    end

    test "delta histogram with no new measurements returns empty" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_histogram(meter, "empty_hist", [])
      Otel.SDK.Metrics.Meter.record(meter, "empty_hist", 10, %{})

      {:ok, [_m1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      {:ok, metrics} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert metrics == []

      GenServer.stop(pid)
    end

    test "delta updown_counter supports negative values" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_updown_counter(meter, "delta_updown", [])
      Otel.SDK.Metrics.Meter.record(meter, "delta_updown", 10, %{})
      Otel.SDK.Metrics.Meter.record(meter, "delta_updown", -3, %{})

      {:ok, [metric1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert metric1.temporality == :delta
      assert metric1.is_monotonic == false
      [dp1] = metric1.datapoints
      assert dp1.value == 7

      Otel.SDK.Metrics.Meter.record(meter, "delta_updown", -5, %{})

      {:ok, [metric2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      [dp2] = metric2.datapoints
      assert dp2.value == -5

      GenServer.stop(pid)
    end

    test "delta start_time advances between collections" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "advancing", [])
      Otel.SDK.Metrics.Meter.record(meter, "advancing", 1, %{})

      {:ok, [m1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      dp1 = hd(m1.datapoints)

      Otel.SDK.Metrics.Meter.record(meter, "advancing", 1, %{})

      {:ok, [m2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      dp2 = hd(m2.datapoints)

      assert dp2.start_time >= dp1.time

      GenServer.stop(pid)
    end

    test "delta with multiple attribute sets" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "multi_attrs", [])
      Otel.SDK.Metrics.Meter.record(meter, "multi_attrs", 5, %{method: "GET"})
      Otel.SDK.Metrics.Meter.record(meter, "multi_attrs", 3, %{method: "POST"})

      {:ok, [metric1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      dps1 = metric1.datapoints
      assert length(dps1) == 2

      Otel.SDK.Metrics.Meter.record(meter, "multi_attrs", 2, %{method: "GET"})

      {:ok, [metric2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      dps2 = metric2.datapoints
      assert length(dps2) == 1
      assert hd(dps2).attributes == %{method: "GET"}
      assert hd(dps2).value == 2

      GenServer.stop(pid)
    end

    test "delta histogram with float values" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_histogram(meter, "float_hist", [])
      Otel.SDK.Metrics.Meter.record(meter, "float_hist", 1.5, %{})
      Otel.SDK.Metrics.Meter.record(meter, "float_hist", 2.5, %{})

      {:ok, [m1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      [dp1] = m1.datapoints
      assert_in_delta dp1.value.sum, 4.0, 0.001
      assert dp1.value.count == 2

      Otel.SDK.Metrics.Meter.record(meter, "float_hist", 3.0, %{})

      {:ok, [m2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      [dp2] = m2.datapoints
      assert_in_delta dp2.value.sum, 3.0, 0.001
      assert dp2.value.count == 1

      GenServer.stop(pid)
    end

    test "gauge still has no temporality with delta reader" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_gauge(meter, "delta_gauge", [])
      Otel.SDK.Metrics.Meter.record(meter, "delta_gauge", 42, %{})

      {:ok, [metric]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert metric.temporality == nil
      assert metric.is_monotonic == nil
      assert hd(metric.datapoints).value == 42

      GenServer.stop(pid)
    end

    test "delta float counter values" do
      %{meter: meter, reader_pid: reader_pid, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "float_delta", [])
      Otel.SDK.Metrics.Meter.record(meter, "float_delta", 1.5, %{})
      Otel.SDK.Metrics.Meter.record(meter, "float_delta", 2.5, %{})

      {:ok, [m1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert_in_delta hd(m1.datapoints).value, 4.0, 0.001

      Otel.SDK.Metrics.Meter.record(meter, "float_delta", 1.0, %{})

      {:ok, [m2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(reader_pid)

      assert_in_delta hd(m2.datapoints).value, 1.0, 0.001

      GenServer.stop(pid)
    end
  end

  describe "instrument default temporality mapping" do
    test "synchronous instruments are delta by default" do
      assert Otel.SDK.Metrics.Instrument.temporality(:counter) == :delta
      assert Otel.SDK.Metrics.Instrument.temporality(:updown_counter) == :delta
      assert Otel.SDK.Metrics.Instrument.temporality(:histogram) == :delta
    end

    test "gauge is cumulative by default" do
      assert Otel.SDK.Metrics.Instrument.temporality(:gauge) == :cumulative
    end

    test "asynchronous instruments are cumulative by default" do
      assert Otel.SDK.Metrics.Instrument.temporality(:observable_counter) == :cumulative
      assert Otel.SDK.Metrics.Instrument.temporality(:observable_gauge) == :cumulative
      assert Otel.SDK.Metrics.Instrument.temporality(:observable_updown_counter) == :cumulative
    end

    test "default mapping returns cumulative for all" do
      mapping = Otel.SDK.Metrics.Instrument.default_temporality_mapping()

      Enum.each(mapping, fn {_kind, temporality} ->
        assert temporality == :cumulative
      end)
    end
  end

  describe "monotonic?" do
    test "counter and observable_counter are monotonic" do
      assert Otel.SDK.Metrics.Instrument.monotonic?(:counter) == true
      assert Otel.SDK.Metrics.Instrument.monotonic?(:observable_counter) == true
    end

    test "other instruments are not monotonic" do
      assert Otel.SDK.Metrics.Instrument.monotonic?(:updown_counter) == false
      assert Otel.SDK.Metrics.Instrument.monotonic?(:histogram) == false
      assert Otel.SDK.Metrics.Instrument.monotonic?(:gauge) == false
      assert Otel.SDK.Metrics.Instrument.monotonic?(:observable_gauge) == false
      assert Otel.SDK.Metrics.Instrument.monotonic?(:observable_updown_counter) == false
    end
  end

  describe "multiple readers on same provider" do
    test "delta and cumulative readers do not interfere" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      cumulative_mapping = Otel.SDK.Metrics.Instrument.default_temporality_mapping()

      delta_mapping = %{
        counter: :delta,
        updown_counter: :delta,
        histogram: :delta,
        gauge: :cumulative,
        observable_counter: :delta,
        observable_gauge: :cumulative,
        observable_updown_counter: :delta
      }

      {:ok, pid} =
        Otel.SDK.Metrics.MeterProvider.start_link(
          config: %{
            readers: [
              {Otel.SDK.Metrics.TemporalityTest.DeltaReader,
               %{temporality_mapping: cumulative_mapping}},
              {Otel.SDK.Metrics.TemporalityTest.DeltaReader,
               %{temporality_mapping: delta_mapping}}
            ]
          }
        )

      config = Otel.SDK.Metrics.MeterProvider.config(pid)
      [{_mod, cumulative_pid}, {_mod2, delta_pid}] = config.readers

      {_mod, meter_config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "multi_lib")
      meter = {Otel.SDK.Metrics.Meter, meter_config}

      Otel.SDK.Metrics.Meter.create_counter(meter, "multi_counter", [])
      Otel.SDK.Metrics.Meter.record(meter, "multi_counter", 10, %{})

      {:ok, [cm1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(cumulative_pid)

      {:ok, [dm1]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(delta_pid)

      assert cm1.temporality == :cumulative
      assert dm1.temporality == :delta
      assert hd(cm1.datapoints).value == 10
      assert hd(dm1.datapoints).value == 10

      Otel.SDK.Metrics.Meter.record(meter, "multi_counter", 5, %{})

      {:ok, [cm2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(cumulative_pid)

      {:ok, [dm2]} =
        Otel.SDK.Metrics.TemporalityTest.DeltaReader.collect(delta_pid)

      assert hd(cm2.datapoints).value == 15
      assert hd(dm2.datapoints).value == 5

      GenServer.stop(pid)
    end
  end

  describe "stream temporality assignment" do
    test "stream gets temporality from reader config" do
      %{meter: meter, provider: pid} = setup_delta_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "stream_test", [])
      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "test_lib")

      instrument_key = {config.scope, "stream_test"}
      streams = :ets.lookup(config.streams_tab, instrument_key)
      assert [{^instrument_key, stream}] = streams
      assert stream.temporality == :delta
      assert stream.reader_id != nil

      GenServer.stop(pid)
    end

    test "default streams have cumulative temporality and nil reader_id" do
      %{meter: meter, provider: pid} = setup_default_provider()

      Otel.SDK.Metrics.Meter.create_counter(meter, "default_test", [])
      {_mod, config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "test_lib")

      instrument_key = {config.scope, "default_test"}
      [{^instrument_key, stream}] = :ets.lookup(config.streams_tab, instrument_key)
      assert stream.temporality == :cumulative
      assert stream.reader_id == nil

      GenServer.stop(pid)
    end
  end
end
