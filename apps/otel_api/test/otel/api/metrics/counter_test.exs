defmodule Otel.API.Metrics.CounterTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})

    meter =
      Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "test_lib"})

    %{meter: meter}
  end

  describe "create/2,3" do
    test "creates counter via meter", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :counter, name: "request_count"} =
               Otel.API.Metrics.Counter.create(meter, "request_count")
    end

    test "accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :counter,
               name: "request_count",
               unit: "1",
               description: "Number of requests"
             } =
               Otel.API.Metrics.Counter.create(meter, "request_count",
                 unit: "1",
                 description: "Number of requests"
               )
    end

    test "accepts advisory params", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :counter} =
               Otel.API.Metrics.Counter.create(meter, "request_count",
                 advisory: [explicit_bucket_boundaries: [10, 50, 100]]
               )
    end
  end

  describe "enabled?/1,2" do
    test "returns false for noop", %{meter: meter} do
      instrument = Otel.API.Metrics.Counter.create(meter, "request_count")
      assert false == Otel.API.Metrics.Counter.enabled?(instrument)
    end

    test "accepts opts", %{meter: meter} do
      instrument = Otel.API.Metrics.Counter.create(meter, "request_count")
      assert false == Otel.API.Metrics.Counter.enabled?(instrument, [])
    end
  end

  describe "add/2,3" do
    test "records a value", %{meter: meter} do
      instrument = Otel.API.Metrics.Counter.create(meter, "request_count")
      assert :ok == Otel.API.Metrics.Counter.add(instrument, 1)
    end

    test "records with attributes", %{meter: meter} do
      instrument = Otel.API.Metrics.Counter.create(meter, "request_count")

      assert :ok ==
               Otel.API.Metrics.Counter.add(instrument, 5, %{"http.method" => "GET"})
    end

    test "accepts zero", %{meter: meter} do
      instrument = Otel.API.Metrics.Counter.create(meter, "request_count")
      assert :ok == Otel.API.Metrics.Counter.add(instrument, 0)
    end

    test "accepts float", %{meter: meter} do
      instrument = Otel.API.Metrics.Counter.create(meter, "request_count")
      assert :ok == Otel.API.Metrics.Counter.add(instrument, 1.5)
    end
  end
end
