defmodule Otel.Metrics.TemporalityTest do
  use ExUnit.Case, async: false

  defmodule DeltaReader do
    @moduledoc false
    use GenServer

    def start_link(config), do: GenServer.start_link(__MODULE__, config)

    def collect(pid), do: GenServer.call(pid, :collect)

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def handle_call(:collect, _from, state) do
      {:reply, {:ok, Otel.Metrics.MetricReader.collect(state.meter_config)}, state}
    end
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

  defp default_provider do
    Otel.TestSupport.restart_with(metrics: [readers: []])

    %Otel.Metrics.Meter{config: config} =
      Otel.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: "test_lib"})

    %{meter: %Otel.Metrics.Meter{config: config}, config: config}
  end

  defp delta_provider do
    # restart_with(readers: []) zeroes reader_id; we want a real
    # reader_id for delta-mode tests. Re-seed MeterProvider with a
    # fresh reader_id + delta temporality_mapping, then start a
    # DeltaReader bound to that meter_config.
    Otel.TestSupport.restart_with(metrics: [readers: []])

    state_key = {Otel.Metrics.MeterProvider, :state}
    state = :persistent_term.get(state_key)

    reader_id = make_ref()

    delta_reader_meter_config = %{
      state.reader_meter_config
      | reader_id: reader_id,
        temporality_mapping: @delta_mapping
    }

    :persistent_term.put(state_key, %{
      state
      | reader_id: reader_id,
        reader_meter_config: delta_reader_meter_config
    })

    {:ok, reader_pid} = DeltaReader.start_link(%{meter_config: delta_reader_meter_config})

    %Otel.Metrics.Meter{config: config} =
      Otel.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: "test_lib"})

    %{meter: %Otel.Metrics.Meter{config: config}, reader: reader_pid, config: config}
  end

  describe "default temporality (cumulative for everything except gauges)" do
    # Spec metrics/sdk.md L1290-L1297 — default temporality_mapping
    # is :cumulative for every kind; gauges have no temporality (nil).
    test "every instrument kind reports the right (temporality, is_monotonic) pair" do
      %{meter: meter, config: config} = default_provider()

      cb = fn _ -> [%Otel.Metrics.Measurement{value: 1}] end

      Otel.Metrics.Meter.record(Otel.Metrics.Meter.create_counter(meter, "c", []), 1, %{})

      Otel.Metrics.Meter.record(
        Otel.Metrics.Meter.create_updown_counter(meter, "udc", []),
        1,
        %{}
      )

      Otel.Metrics.Meter.record(Otel.Metrics.Meter.create_histogram(meter, "h", []), 1, %{})
      Otel.Metrics.Meter.record(Otel.Metrics.Meter.create_gauge(meter, "g", []), 1, %{})
      Otel.Metrics.Meter.create_observable_counter(meter, "oc", cb, nil, [])
      Otel.Metrics.Meter.create_observable_gauge(meter, "og", cb, nil, [])
      Otel.Metrics.Meter.create_observable_updown_counter(meter, "oudc", cb, nil, [])

      by_name =
        Otel.Metrics.MetricReader.collect(config) |> Map.new(&{&1.name, &1})

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

      counter = Otel.Metrics.Meter.create_counter(meter, "stable", [])
      Otel.Metrics.Meter.record(counter, 5, %{})
      Otel.Metrics.Meter.record(counter, 3, %{})

      [m1] = Otel.Metrics.MetricReader.collect(config)
      [dp1] = m1.datapoints
      assert dp1.value == 8

      Otel.Metrics.Meter.record(counter, 2, %{})
      [m2] = Otel.Metrics.MetricReader.collect(config)
      [dp2] = m2.datapoints
      assert dp2.value == 10
      assert dp2.start_time == dp1.start_time
    end

    test "histogram preserves cumulative count + sum across collections" do
      %{meter: meter, config: config} = default_provider()
      hist = Otel.Metrics.Meter.create_histogram(meter, "latency", [])

      Otel.Metrics.Meter.record(hist, 50, %{})
      Otel.Metrics.Meter.record(hist, 150, %{})
      _ = Otel.Metrics.MetricReader.collect(config)

      Otel.Metrics.Meter.record(hist, 200, %{})
      [m] = Otel.Metrics.MetricReader.collect(config)
      [dp] = m.datapoints
      assert dp.value.count == 3
      assert dp.value.sum == 400
    end
  end

  describe "delta temporality via custom reader" do
    test "counter values reset between collections; start_time advances" do
      %{meter: meter, reader: reader} = delta_provider()
      counter = Otel.Metrics.Meter.create_counter(meter, "delta_counter", [])

      Otel.Metrics.Meter.record(counter, 5, %{})
      Otel.Metrics.Meter.record(counter, 3, %{})

      {:ok, [m1]} = DeltaReader.collect(reader)
      [dp1] = m1.datapoints
      assert m1.temporality == :delta
      assert m1.is_monotonic == true
      assert dp1.value == 8

      Otel.Metrics.Meter.record(counter, 2, %{})
      {:ok, [m2]} = DeltaReader.collect(reader)
      [dp2] = m2.datapoints
      assert dp2.value == 2
      assert dp2.start_time >= dp1.time
    end

    test "no measurements between collections → empty result (counter and histogram)" do
      %{meter: meter, reader: reader} = delta_provider()

      counter = Otel.Metrics.Meter.create_counter(meter, "empty_counter", [])
      hist = Otel.Metrics.Meter.create_histogram(meter, "empty_hist", [])
      Otel.Metrics.Meter.record(counter, 5, %{})
      Otel.Metrics.Meter.record(hist, 10, %{})

      {:ok, [_, _]} = DeltaReader.collect(reader)
      {:ok, []} = DeltaReader.collect(reader)
    end

    test "histogram resets count, sum, min, max between collections" do
      %{meter: meter, reader: reader} = delta_provider()
      hist = Otel.Metrics.Meter.create_histogram(meter, "delta_latency", [])

      Otel.Metrics.Meter.record(hist, 50, %{})
      Otel.Metrics.Meter.record(hist, 150, %{})

      {:ok, [m1]} = DeltaReader.collect(reader)
      [dp1] = m1.datapoints
      assert m1.temporality == :delta
      assert dp1.value.count == 2
      assert dp1.value.sum == 200
      assert dp1.value.min == 50
      assert dp1.value.max == 150

      Otel.Metrics.Meter.record(hist, 75, %{})
      {:ok, [m2]} = DeltaReader.collect(reader)
      [dp2] = m2.datapoints
      assert dp2.value.count == 1
      assert dp2.value.sum == 75
      assert dp2.value.min == 75
      assert dp2.value.max == 75
    end

    test "updown_counter supports negative deltas; multi-attr only emits attrs that changed" do
      %{meter: meter, reader: reader} = delta_provider()

      udc = Otel.Metrics.Meter.create_updown_counter(meter, "udc", [])
      multi = Otel.Metrics.Meter.create_counter(meter, "multi", [])

      Otel.Metrics.Meter.record(udc, 7, %{})
      Otel.Metrics.Meter.record(multi, 1, %{"method" => "GET"})
      Otel.Metrics.Meter.record(multi, 2, %{"method" => "POST"})

      {:ok, ms} = DeltaReader.collect(reader)
      by_name = Map.new(ms, &{&1.name, &1})

      assert hd(by_name["udc"].datapoints).value == 7
      assert length(by_name["multi"].datapoints) == 2

      Otel.Metrics.Meter.record(udc, -5, %{})
      Otel.Metrics.Meter.record(multi, 2, %{"method" => "GET"})

      {:ok, ms2} = DeltaReader.collect(reader)
      by_name2 = Map.new(ms2, &{&1.name, &1})

      assert hd(by_name2["udc"].datapoints).value == -5
      assert length(by_name2["multi"].datapoints) == 1
      assert hd(by_name2["multi"].datapoints).attributes == %{"method" => "GET"}
    end

    test "gauge ignores reader's delta mapping (no temporality)" do
      %{meter: meter, reader: reader} = delta_provider()
      gauge = Otel.Metrics.Meter.create_gauge(meter, "g", [])
      Otel.Metrics.Meter.record(gauge, 42, %{})

      {:ok, [m]} = DeltaReader.collect(reader)
      assert m.temporality == nil
      assert m.is_monotonic == nil
      assert hd(m.datapoints).value == 42
    end
  end

  test "stream temporality + reader_id come from the reader's temporality_mapping" do
    %{config: delta_config} = delta_provider()

    _ =
      Otel.Metrics.Meter.create_counter(
        %Otel.Metrics.Meter{config: delta_config},
        "delta_stream",
        []
      )

    [{_, stream}] = :ets.lookup(delta_config.streams_tab, {delta_config.scope, "delta_stream"})
    assert stream.temporality == :delta
    assert stream.reader_id != nil
  end
end
