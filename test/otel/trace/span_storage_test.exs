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
    start_time: System.system_time(:nanosecond)
  }

  describe "insert_active/1 + get_active/1 + update_active/2" do
    test "insert_active → get_active returns the span; get_active on missing key → nil" do
      assert :ok = Otel.Trace.SpanStorage.insert_active(@span)

      assert %Otel.Trace.Span{name: "test_span", trace_id: tid} =
               Otel.Trace.SpanStorage.get_active(@span.span_id)

      assert tid == @span.trace_id
      assert Otel.Trace.SpanStorage.get_active(999) == nil
    end

    test "update_active applies fun and writes back; no-op on missing key" do
      Otel.Trace.SpanStorage.insert_active(@span)
      Otel.Trace.SpanStorage.update_active(@span.span_id, fn s -> %{s | name: "renamed"} end)

      assert Otel.Trace.SpanStorage.get_active(@span.span_id).name == "renamed"

      # Missing key — no-op, no crash.
      assert :ok = Otel.Trace.SpanStorage.update_active(999, fn _ -> raise "should not run" end)
    end
  end

  describe "mark_completed/2 + take_completed/1" do
    test "mark_completed flips status; take_completed yields it once" do
      Otel.Trace.SpanStorage.insert_active(@span)

      assert %Otel.Trace.Span{end_time: end_time} =
               Otel.Trace.SpanStorage.mark_completed(@span.span_id, 1_234)

      assert end_time == 1_234

      # update_active no longer affects this span (status is :completed).
      Otel.Trace.SpanStorage.update_active(@span.span_id, fn s -> %{s | name: "noop"} end)
      assert Otel.Trace.SpanStorage.get_active(@span.span_id) == nil

      # take_completed returns the completed span.
      assert [%Otel.Trace.Span{span_id: sid, name: "test_span", end_time: 1_234}] =
               Otel.Trace.SpanStorage.take_completed(10)

      assert sid == @span.span_id

      # Subsequent take returns empty (already taken + deleted).
      assert [] = Otel.Trace.SpanStorage.take_completed(10)
    end

    test "mark_completed on missing span → nil" do
      assert nil == Otel.Trace.SpanStorage.mark_completed(999, 1_000)
    end

    test "take_completed only returns :completed, leaves :active alone" do
      active = %{@span | span_id: 1}
      will_complete = %{@span | span_id: 2}

      Otel.Trace.SpanStorage.insert_active(active)
      Otel.Trace.SpanStorage.insert_active(will_complete)
      Otel.Trace.SpanStorage.mark_completed(2, 500)

      assert [%Otel.Trace.Span{span_id: 2}] = Otel.Trace.SpanStorage.take_completed(10)
      assert %Otel.Trace.Span{} = Otel.Trace.SpanStorage.get_active(1)
    end
  end

  test "ETS table is named, public, and write-concurrent" do
    info = :ets.info(Otel.Trace.SpanStorage)

    assert info[:named_table] == true
    assert info[:protection] == :public
    assert info[:write_concurrency] != false
  end
end
