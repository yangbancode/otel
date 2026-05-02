defmodule Otel.Trace.SpanStorageTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
    :ok
  end

  @span %Otel.Trace.Span{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    name: "test_span",
    kind: :internal,
    start_time: System.system_time(:nanosecond),
    is_recording: true
  }

  describe "insert/1 + get/1 + take/1" do
    test "round-trip: insert → get returns the span; get on a missing key → nil" do
      assert true == Otel.Trace.SpanStorage.insert(@span)

      assert %Otel.Trace.Span{name: "test_span", trace_id: trace_id} =
               Otel.Trace.SpanStorage.get(@span.span_id)

      assert trace_id == @span.trace_id
      assert Otel.Trace.SpanStorage.get(999) == nil
    end

    test "take/1 removes and returns the span; take on a missing key → nil" do
      Otel.Trace.SpanStorage.insert(@span)

      assert %Otel.Trace.Span{name: "test_span"} =
               Otel.Trace.SpanStorage.take(@span.span_id)

      assert Otel.Trace.SpanStorage.get(@span.span_id) == nil
      assert Otel.Trace.SpanStorage.take(999) == nil
    end

    test "re-insert under the same span_id replaces the existing entry" do
      Otel.Trace.SpanStorage.insert(@span)
      Otel.Trace.SpanStorage.insert(%{@span | name: "updated_name"})

      assert Otel.Trace.SpanStorage.get(@span.span_id).name == "updated_name"
    end
  end

  test "ETS table is named, public, and write-concurrent" do
    info = :ets.info(Otel.Trace.SpanStorage.table())

    assert info[:named_table] == true
    assert info[:protection] == :public
    assert info[:write_concurrency] != false
  end
end
