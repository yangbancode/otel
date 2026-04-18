defmodule Otel.API.Metrics.HistogramTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3" do
    test "creates histogram via meter", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :histogram, name: "request_duration"} =
               Otel.API.Metrics.Histogram.create(meter, "request_duration")
    end

    test "accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :histogram,
               unit: "ms",
               description: "Request duration in milliseconds"
             } =
               Otel.API.Metrics.Histogram.create(meter, "request_duration",
                 unit: "ms",
                 description: "Request duration in milliseconds"
               )
    end

    test "accepts explicit_bucket_boundaries advisory", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :histogram} =
               Otel.API.Metrics.Histogram.create(meter, "request_duration",
                 advisory: [
                   explicit_bucket_boundaries: [0, 5, 10, 25, 50, 75, 100, 250, 500, 1000]
                 ]
               )
    end
  end

  describe "enabled?/1,2" do
    test "returns false for noop", %{meter: meter} do
      instrument = Otel.API.Metrics.Histogram.create(meter, "request_duration")
      assert false == Otel.API.Metrics.Histogram.enabled?(instrument)
    end

    test "accepts opts", %{meter: meter} do
      instrument = Otel.API.Metrics.Histogram.create(meter, "request_duration")
      assert false == Otel.API.Metrics.Histogram.enabled?(instrument, [])
    end
  end

  describe "record/2,3" do
    test "records a value", %{meter: meter} do
      instrument = Otel.API.Metrics.Histogram.create(meter, "request_duration")
      assert :ok == Otel.API.Metrics.Histogram.record(instrument, 42)
    end

    test "records with attributes", %{meter: meter} do
      instrument = Otel.API.Metrics.Histogram.create(meter, "request_duration")

      assert :ok ==
               Otel.API.Metrics.Histogram.record(instrument, 150, %{"http.method" => "POST"})
    end

    test "accepts zero", %{meter: meter} do
      instrument = Otel.API.Metrics.Histogram.create(meter, "request_duration")
      assert :ok == Otel.API.Metrics.Histogram.record(instrument, 0)
    end

    test "accepts float", %{meter: meter} do
      instrument = Otel.API.Metrics.Histogram.create(meter, "request_duration")
      assert :ok == Otel.API.Metrics.Histogram.record(instrument, 3.14)
    end
  end
end
