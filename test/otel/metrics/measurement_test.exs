defmodule Otel.Metrics.MeasurementTest do
  use ExUnit.Case, async: true

  test "default struct has value 0 and empty attributes" do
    assert %Otel.Metrics.Measurement{} ==
             %Otel.Metrics.Measurement{value: 0, attributes: %{}}
  end

  test "literal preserves explicit value and attributes" do
    m = %Otel.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}
    assert m.value == 42
    assert m.attributes == %{"host" => "a"}
  end
end
