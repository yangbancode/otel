defmodule Otel.Metrics.ExemplarTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "default struct uses proto3 zero values" do
      assert Otel.Metrics.Exemplar.new() ==
               %Otel.Metrics.Exemplar{
                 value: 0,
                 time: 0,
                 filtered_attributes: %{},
                 trace_id: 0,
                 span_id: 0
               }
    end

    test "preserves caller-supplied trace_id / span_id verbatim" do
      exemplar =
        Otel.Metrics.Exemplar.new(%{
          value: 42,
          time: 1000,
          filtered_attributes: %{"key" => "val"},
          trace_id: 123,
          span_id: 456
        })

      assert exemplar.value == 42
      assert exemplar.time == 1000
      assert exemplar.filtered_attributes == %{"key" => "val"}
      assert exemplar.trace_id == 123
      assert exemplar.span_id == 456
    end
  end
end
