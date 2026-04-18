defmodule Otel.API.Metrics.MeasurementTest do
  use ExUnit.Case, async: true

  describe "new/1,2" do
    test "creates a measurement with just a value" do
      m = Otel.API.Metrics.Measurement.new(42)
      assert m.value == 42
      assert m.attributes == %{}
    end

    test "creates a measurement with value and attributes" do
      m = Otel.API.Metrics.Measurement.new(3.14, %{"host" => "a"})
      assert m.value == 3.14
      assert m.attributes == %{"host" => "a"}
    end

    test "accepts integer values" do
      m = Otel.API.Metrics.Measurement.new(100, %{"k" => "v"})
      assert m.value == 100
    end

    test "accepts float values" do
      m = Otel.API.Metrics.Measurement.new(0.5, %{})
      assert m.value == 0.5
    end

    test "accepts negative values" do
      m = Otel.API.Metrics.Measurement.new(-7)
      assert m.value == -7
    end

    test "returns a struct of the expected type" do
      m = Otel.API.Metrics.Measurement.new(1)
      assert %Otel.API.Metrics.Measurement{} = m
    end
  end

  describe "struct defaults" do
    test "value defaults to 0" do
      m = %Otel.API.Metrics.Measurement{}
      assert m.value == 0
    end

    test "attributes defaults to empty map" do
      m = %Otel.API.Metrics.Measurement{}
      assert m.attributes == %{}
    end
  end
end
