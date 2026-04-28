defmodule Otel.SDK.Trace.SpanLimitsTest do
  use ExUnit.Case, async: true

  describe "defaults" do
    test "attribute_count_limit defaults to 128" do
      assert %Otel.SDK.Trace.SpanLimits{}.attribute_count_limit == 128
    end

    test "attribute_value_length_limit defaults to infinity" do
      assert %Otel.SDK.Trace.SpanLimits{}.attribute_value_length_limit == :infinity
    end

    test "event_count_limit defaults to 128" do
      assert %Otel.SDK.Trace.SpanLimits{}.event_count_limit == 128
    end

    test "link_count_limit defaults to 128" do
      assert %Otel.SDK.Trace.SpanLimits{}.link_count_limit == 128
    end

    test "attribute_per_event_limit defaults to 128" do
      assert %Otel.SDK.Trace.SpanLimits{}.attribute_per_event_limit == 128
    end

    test "attribute_per_link_limit defaults to 128" do
      assert %Otel.SDK.Trace.SpanLimits{}.attribute_per_link_limit == 128
    end
  end

  describe "custom values" do
    test "accepts custom limits" do
      limits = %Otel.SDK.Trace.SpanLimits{
        attribute_count_limit: 64,
        attribute_value_length_limit: 256,
        event_count_limit: 32,
        link_count_limit: 16,
        attribute_per_event_limit: 8,
        attribute_per_link_limit: 4
      }

      assert limits.attribute_count_limit == 64
      assert limits.attribute_value_length_limit == 256
      assert limits.event_count_limit == 32
      assert limits.link_count_limit == 16
      assert limits.attribute_per_event_limit == 8
      assert limits.attribute_per_link_limit == 4
    end
  end
end
