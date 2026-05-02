defmodule Otel.API.Metrics.MeterTest do
  use ExUnit.Case, async: false

  # Verifies the facade dispatches through to the registered Meter
  # module. Behaviour of the Noop fallback itself is covered in
  # `Otel.API.Metrics.Meter.NoopTest`; here we only need to confirm
  # that each facade function reaches the Meter dispatch.

  setup do
    saved = :persistent_term.get({Otel.API.Metrics.MeterProvider, :global}, nil)
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})

    on_exit(fn ->
      if saved,
        do: :persistent_term.put({Otel.API.Metrics.MeterProvider, :global}, saved),
        else: :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    end)

    %{
      meter: Otel.API.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: "test"})
    }
  end

  test "create_* sync instruments dispatch and forward opts", %{meter: meter} do
    assert %Otel.API.Metrics.Instrument{kind: :counter, name: "c", unit: "ms"} =
             Otel.API.Metrics.Meter.create_counter(meter, "c", unit: "ms")

    assert %Otel.API.Metrics.Instrument{kind: :updown_counter, name: "udc"} =
             Otel.API.Metrics.Meter.create_updown_counter(meter, "udc")

    assert %Otel.API.Metrics.Instrument{kind: :histogram, name: "h", description: "d"} =
             Otel.API.Metrics.Meter.create_histogram(meter, "h", description: "d")

    assert %Otel.API.Metrics.Instrument{kind: :gauge, name: "g"} =
             Otel.API.Metrics.Meter.create_gauge(meter, "g")
  end

  test "create_* async instruments without callback", %{meter: meter} do
    assert %Otel.API.Metrics.Instrument{kind: :observable_counter, name: "oc"} =
             Otel.API.Metrics.Meter.create_observable_counter(meter, "oc")

    assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter, name: "oudc"} =
             Otel.API.Metrics.Meter.create_observable_updown_counter(meter, "oudc")

    assert %Otel.API.Metrics.Instrument{kind: :observable_gauge, name: "og"} =
             Otel.API.Metrics.Meter.create_observable_gauge(meter, "og")
  end

  test "create_* async instruments with inline callback", %{meter: meter} do
    cb = fn _args -> [%Otel.API.Metrics.Measurement{value: 1}] end

    assert %Otel.API.Metrics.Instrument{kind: :observable_counter} =
             Otel.API.Metrics.Meter.create_observable_counter(meter, "oc", cb, nil, [])

    assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} =
             Otel.API.Metrics.Meter.create_observable_updown_counter(meter, "oudc", cb, nil, [])

    assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} =
             Otel.API.Metrics.Meter.create_observable_gauge(meter, "og", cb, nil, [])
  end

  test "record/3 dispatches; with and without attributes", %{meter: meter} do
    inst = Otel.API.Metrics.Meter.create_counter(meter, "c")
    assert :ok = Otel.API.Metrics.Meter.record(inst, 1)
    assert :ok = Otel.API.Metrics.Meter.record(inst, 1, %{"key" => "val"})
  end

  test "register_callback/4,5 + unregister_callback/1 dispatch", %{meter: meter} do
    cb = fn _args -> [] end

    assert {Otel.API.Metrics.Meter.Noop, :noop} =
             reg = Otel.API.Metrics.Meter.register_callback(meter, [], cb, nil)

    assert {Otel.API.Metrics.Meter.Noop, :noop} =
             Otel.API.Metrics.Meter.register_callback(meter, [], cb, nil, [])

    assert :ok = Otel.API.Metrics.Meter.unregister_callback(reg)
  end

  test "enabled?/2 dispatches and returns false under Noop", %{meter: meter} do
    inst = Otel.API.Metrics.Meter.create_counter(meter, "c")
    refute Otel.API.Metrics.Meter.enabled?(inst)
    refute Otel.API.Metrics.Meter.enabled?(inst, [])
  end
end
