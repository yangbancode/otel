defmodule Otel.Trace.SpanLimitsTest do
  use ExUnit.Case, async: true

  # Spec trace/sdk.md L1118-L1129 — every Span limit defaults to 128
  # entries; attribute value length is unlimited (:infinity) by default.
  test "default struct has spec-mandated defaults" do
    assert %Otel.Trace.SpanLimits{} == %Otel.Trace.SpanLimits{
             attribute_count_limit: 128,
             attribute_value_length_limit: :infinity,
             event_count_limit: 128,
             link_count_limit: 128,
             attribute_per_event_limit: 128,
             attribute_per_link_limit: 128
           }
  end

  test "literal preserves any custom limit values" do
    limits = %Otel.Trace.SpanLimits{
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
