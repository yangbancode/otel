defmodule Otel.SDK.Metrics.TemporalityTest do
  use ExUnit.Case, async: false

  defmodule DeltaReader do
    @moduledoc false
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
      {:reply, {:ok, Otel.SDK.Metrics.MetricReader.collect(state.meter_config)}, state}
    end

    def handle_call(:shutdown, _from, state), do: {:reply, :ok, state}
    def handle_call(:force_flush, _from, state), do: {:reply, :ok, state}
  end

  @delta_mapping %{
    counter: :delta,
    updown_counter: :delta,
    histogram: :delta,
    gauge: :cumulative,
    observable_counter: :delta,
    observable_gauge: :cumulative,
    observable_updown_counter: :delta
  }

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)
  end

  defp default_provider do
    restart_sdk(metrics: [exporter: :none])

    {_, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.API.InstrumentationScope{name: "test_lib"}
      )

    %{meter: {Otel.SDK.Metrics.Meter, config}, config: config}
  end

  defp delta_provider do
    restart_sdk(metrics: [readers: [{DeltaReader, %{temporality_mapping: @delta_mapping}}]])

    [{_, reader_pid}] = :sys.get_state(Otel.SDK.Metrics.MeterProvider).readers

    {_, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.API.InstrumentationScope{name: "test_lib"}
      )

    %{meter: {Otel.SDK.Metrics.Meter, config}, reader: reader_pid, config: config}
  end

  describe "default temporality (cumulative for everything except gauges)" do
    # Spec metrics/sdk.md L1290-L1297 — default temporality_mapping
    # is :cumulative for every kind; gauges have no temporality (nil).
    test "every instrument kind reports the right (temporality, is_monotonic) pair" do
      %{meter: meter, config: config} = default_provider()

      cb = fn _ -> [%Otel.API.Metrics.Measurement{value: 1}] end

      Otel.SDK.Metrics.Meter.record(
        Otel.SDK.Metrics.Meter.create_counter(meter, "c", []),
        1,
        %{}
      )

      Otel.SDK.Metrics.Meter.record(
        Otel.SDK.Metrics.Meter.create_updown_counter(meter, "udc", []),
        1,
        %{}
      )

      Otel.SDK.Metrics.Meter.record(
        Otel.SDK.Metrics.Meter.create_histogram(meter, "h", []),
        1,
        %{}
      )

      Otel.SDK.Metrics.Meter.record(
        Otel.SDK.Metrics.Meter.create_gauge(meter, "g", []),
        1,
        %{}
      )

      Otel.SDK.Metrics.Meter.create_observable_counter(meter, "oc", cb, nil, [])
      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "og", cb, nil, [])
      Otel.SDK.Metrics.Meter.create_observable_updown_counter(meter, "oudc", cb, nil, [])

      by_name =
        Otel.SDK.Metrics.MetricReader.collect(config) |> Map.new(&{&1.name, &1})

      assert {:cumulative, true} = {by_name["c"].temporality, by_name["c"].is_monotonic}
      assert {:cumulative, false} = {by_name["udc"].temporality, by_name["udc"].is_monotonic}
      assert {:cumulative, false} = {by_name["h"].temporality, by_name["h"].is_monotonic}
      assert {nil, nil} = {by_name["g"].temporality, by_name["g"].is_monotonic}
      assert {:cumulative, true} = {by_name["oc"].temporality, by_name["oc"].is_monotonic}
      assert {nil, nil} = {by_name["og"].temporality, by_name["og"].is_monotonic}
      assert {:cumulative, false} = {by_name["oudc"].temporality, by_name["oudc"].is_monotonic}
    end

    test "cumulative datapoints carry stable start_time across collections; sums accumulate" do
      %{meter: meter, config: config} = default_provider()

      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "stable", [])
      Otel.SDK.Metrics.Meter.record(counter, 5, %{})
      Otel.SDK.Metrics.Meter.record(counter, 3, %{})

      [m1] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp1] = m1.datapoints
      assert dp1.value == 8

      Otel.SDK.Metrics.Meter.record(counter, 2, %{})
      [m2] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp2] = m2.datapoints
      assert dp2.value == 10
      assert dp2.start_time == dp1.start_time
    end

    test "histogram preserves cumulative count + sum across collections" do
      %{meter: meter, config: config} = default_provider()
      hist = Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", [])

      Otel.SDK.Metrics.Meter.record(hist, 50, %{})
      Otel.SDK.Metrics.Meter.record(hist, 150, %{})
      _ = Otel.SDK.Metrics.MetricReader.collect(config)

      Otel.SDK.Metrics.Meter.record(hist, 200, %{})
      [m] = Otel.SDK.Metrics.MetricReader.collect(config)
      [dp] = m.datapoints
      assert dp.value.count == 3
      assert dp.value.sum == 400
    end
  end

  describe "delta temporality via custom reader" do
    test "counter values reset between collections; start_time advances" do
      %{meter: meter, reader: reader} = delta_provider()
      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "delta_counter", [])

      Otel.SDK.Metrics.Meter.record(counter, 5, %{})
      Otel.SDK.Metrics.Meter.record(counter, 3, %{})

      {:ok, [m1]} = DeltaReader.collect(reader)
      [dp1] = m1.datapoints
      assert m1.temporality == :delta
      assert m1.is_monotonic == true
      assert dp1.value == 8

      Otel.SDK.Metrics.Meter.record(counter, 2, %{})
      {:ok, [m2]} = DeltaReader.collect(reader)
      [dp2] = m2.datapoints
      assert dp2.value == 2
      assert dp2.start_time >= dp1.time
    end

    test "no measurements between collections → empty result (counter and histogram)" do
      %{meter: meter, reader: reader} = delta_provider()

      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "empty_counter", [])
      hist = Otel.SDK.Metrics.Meter.create_histogram(meter, "empty_hist", [])
      Otel.SDK.Metrics.Meter.record(counter, 5, %{})
      Otel.SDK.Metrics.Meter.record(hist, 10, %{})

      {:ok, [_, _]} = DeltaReader.collect(reader)
      {:ok, []} = DeltaReader.collect(reader)
    end

    test "histogram resets count, sum, min, max between collections" do
      %{meter: meter, reader: reader} = delta_provider()
      hist = Otel.SDK.Metrics.Meter.create_histogram(meter, "delta_latency", [])

      Otel.SDK.Metrics.Meter.record(hist, 50, %{})
      Otel.SDK.Metrics.Meter.record(hist, 150, %{})

      {:ok, [m1]} = DeltaReader.collect(reader)
      [dp1] = m1.datapoints
      assert m1.temporality == :delta
      assert dp1.value.count == 2
      assert dp1.value.sum == 200
      assert dp1.value.min == 50
      assert dp1.value.max == 150

      Otel.SDK.Metrics.Meter.record(hist, 300, %{})
      {:ok, [m2]} = DeltaReader.collect(reader)
      [dp2] = m2.datapoints
      assert dp2.value.count == 1
      assert dp2.value.sum == 300
      assert dp2.value.min == 300
      assert dp2.value.max == 300
    end

    test "updown_counter supports negative deltas; multi-attr only emits attrs that changed" do
      %{meter: meter, reader: reader} = delta_provider()
      udc = Otel.SDK.Metrics.Meter.create_updown_counter(meter, "udc", [])
      multi = Otel.SDK.Metrics.Meter.create_counter(meter, "multi", [])

      Otel.SDK.Metrics.Meter.record(udc, 10, %{})
      Otel.SDK.Metrics.Meter.record(udc, -3, %{})
      Otel.SDK.Metrics.Meter.record(multi, 5, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(multi, 3, %{"method" => "POST"})

      {:ok, ms} = DeltaReader.collect(reader)
      by_name = Map.new(ms, &{&1.name, &1})

      assert by_name["udc"].is_monotonic == false
      assert hd(by_name["udc"].datapoints).value == 7
      assert length(by_name["multi"].datapoints) == 2

      Otel.SDK.Metrics.Meter.record(udc, -5, %{})
      Otel.SDK.Metrics.Meter.record(multi, 2, %{"method" => "GET"})

      {:ok, ms2} = DeltaReader.collect(reader)
      by_name2 = Map.new(ms2, &{&1.name, &1})

      assert hd(by_name2["udc"].datapoints).value == -5
      assert length(by_name2["multi"].datapoints) == 1
      assert hd(by_name2["multi"].datapoints).attributes == %{"method" => "GET"}
    end

    test "gauge ignores reader's delta mapping (no temporality)" do
      %{meter: meter, reader: reader} = delta_provider()
      gauge = Otel.SDK.Metrics.Meter.create_gauge(meter, "g", [])
      Otel.SDK.Metrics.Meter.record(gauge, 42, %{})

      {:ok, [m]} = DeltaReader.collect(reader)
      assert m.temporality == nil
      assert m.is_monotonic == nil
      assert hd(m.datapoints).value == 42
    end
  end

  test "delta + cumulative readers on the same provider don't interfere with each other" do
    restart_sdk(
      metrics: [
        readers: [
          {DeltaReader,
           %{temporality_mapping: Otel.API.Metrics.Instrument.default_temporality_mapping()}},
          {DeltaReader, %{temporality_mapping: @delta_mapping}}
        ]
      ]
    )

    [{_, cumulative}, {_, delta}] = :sys.get_state(Otel.SDK.Metrics.MeterProvider).readers

    {_, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.API.InstrumentationScope{name: "multi_lib"}
      )

    counter = Otel.SDK.Metrics.Meter.create_counter({Otel.SDK.Metrics.Meter, config}, "c", [])
    Otel.SDK.Metrics.Meter.record(counter, 10, %{})

    {:ok, [cm1]} = DeltaReader.collect(cumulative)
    {:ok, [dm1]} = DeltaReader.collect(delta)
    assert cm1.temporality == :cumulative
    assert dm1.temporality == :delta
    assert hd(cm1.datapoints).value == 10
    assert hd(dm1.datapoints).value == 10

    Otel.SDK.Metrics.Meter.record(counter, 5, %{})
    {:ok, [cm2]} = DeltaReader.collect(cumulative)
    {:ok, [dm2]} = DeltaReader.collect(delta)
    assert hd(cm2.datapoints).value == 15
    assert hd(dm2.datapoints).value == 5
  end

  test "stream temporality + reader_id come from the reader's temporality_mapping" do
    %{config: delta_config} = delta_provider()

    counter_in_delta =
      Otel.SDK.Metrics.Meter.create_counter(
        {Otel.SDK.Metrics.Meter, delta_config},
        "delta_stream",
        []
      )

    _ = counter_in_delta

    [{_, stream}] = :ets.lookup(delta_config.streams_tab, {delta_config.scope, "delta_stream"})
    assert stream.temporality == :delta
    assert stream.reader_id != nil

    %{config: cumulative_config} = default_provider()

    counter_in_cumulative =
      Otel.SDK.Metrics.Meter.create_counter(
        {Otel.SDK.Metrics.Meter, cumulative_config},
        "cum_stream",
        []
      )

    _ = counter_in_cumulative

    [{_, stream}] =
      :ets.lookup(cumulative_config.streams_tab, {cumulative_config.scope, "cum_stream"})

    assert stream.temporality == :cumulative
    assert stream.reader_id == nil
  end
end
