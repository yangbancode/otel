defmodule Otel.API.Metrics.UpDownCounterTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3" do
    test "creates updown_counter via meter", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :updown_counter, name: "active_requests"} =
               Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
    end

    test "accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :updown_counter,
               unit: "1",
               description: "Number of active requests"
             } =
               Otel.API.Metrics.UpDownCounter.create(meter, "active_requests",
                 unit: "1",
                 description: "Number of active requests"
               )
    end
  end

  describe "enabled?/1,2" do
    test "returns false for noop", %{meter: meter} do
      instrument = Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
      assert false == Otel.API.Metrics.UpDownCounter.enabled?(instrument)
    end

    test "accepts opts", %{meter: meter} do
      instrument = Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
      assert false == Otel.API.Metrics.UpDownCounter.enabled?(instrument, [])
    end
  end

  describe "add/2,3" do
    test "records a positive value", %{meter: meter} do
      instrument = Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
      assert :ok == Otel.API.Metrics.UpDownCounter.add(instrument, 1)
    end

    test "records a negative value", %{meter: meter} do
      instrument = Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
      assert :ok == Otel.API.Metrics.UpDownCounter.add(instrument, -1)
    end

    test "records with attributes", %{meter: meter} do
      instrument = Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")

      assert :ok ==
               Otel.API.Metrics.UpDownCounter.add(instrument, 3, %{"http.method" => "GET"})
    end

    test "accepts zero", %{meter: meter} do
      instrument = Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
      assert :ok == Otel.API.Metrics.UpDownCounter.add(instrument, 0)
    end

    test "accepts float", %{meter: meter} do
      instrument = Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
      assert :ok == Otel.API.Metrics.UpDownCounter.add(instrument, -0.5)
    end
  end
end
