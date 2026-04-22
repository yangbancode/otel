defmodule Otel.API.Metrics.MeasurementTest do
  use ExUnit.Case, async: true

  describe "struct" do
    test "defaults: value is 0, attributes is empty map" do
      m = %Otel.API.Metrics.Measurement{}
      assert m.value == 0
      assert m.attributes == %{}
    end

    test "constructed with explicit value and attributes" do
      m = %Otel.API.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}
      assert m.value == 42
      assert m.attributes == %{"host" => "a"}
    end
  end
end
