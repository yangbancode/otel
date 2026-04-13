defmodule Otel.API.Metrics.CounterTest do
  use ExUnit.Case

  setup do
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3" do
    test "creates counter via meter", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Counter.create(meter, "request_count")
    end

    test "accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Counter.create(meter, "request_count",
                 unit: "1",
                 description: "Number of requests"
               )
    end

    test "accepts advisory params", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Counter.create(meter, "request_count",
                 advisory: [explicit_bucket_boundaries: [10, 50, 100]]
               )
    end
  end

  describe "enabled?/1,2" do
    test "returns false for noop", %{meter: meter} do
      assert false == Otel.API.Metrics.Counter.enabled?(meter)
    end

    test "accepts opts", %{meter: meter} do
      assert false == Otel.API.Metrics.Counter.enabled?(meter, [])
    end
  end

  describe "add/3,4" do
    test "records a value", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Counter.add(meter, "request_count", 1)
    end

    test "records with attributes", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Counter.add(meter, "request_count", 5, %{
                 "http.method" => "GET"
               })
    end

    test "accepts zero", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Counter.add(meter, "request_count", 0)
    end

    test "accepts float", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Counter.add(meter, "request_count", 1.5)
    end
  end
end
