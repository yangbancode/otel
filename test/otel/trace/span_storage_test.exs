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

  describe "insert/1 + get/1 + update/1" do
    test "insert → get returns the span; get on missing key → nil" do
      assert :ok = Otel.Trace.SpanStorage.insert(@span)

      assert %Otel.Trace.Span{name: "test_span", trace_id: tid} =
               Otel.Trace.SpanStorage.get(@span.span_id)

      assert tid == @span.trace_id
      assert Otel.Trace.SpanStorage.get(999) == nil
    end

    test "update replaces an active span; no-op on missing key" do
      Otel.Trace.SpanStorage.insert(@span)
      Otel.Trace.SpanStorage.update(%{@span | name: "renamed"})

      assert Otel.Trace.SpanStorage.get(@span.span_id).name == "renamed"

      # Missing key — no-op (no row matched the select_replace spec).
      assert :ok = Otel.Trace.SpanStorage.update(%{@span | span_id: 999, name: "noop"})
      assert Otel.Trace.SpanStorage.get(999) == nil
    end
  end

  describe "mark_completed/2 + take_completed/1" do
    test "mark_completed flips status; take_completed yields it once" do
      Otel.Trace.SpanStorage.insert(@span)

      assert %Otel.Trace.Span{end_time: end_time} =
               Otel.Trace.SpanStorage.mark_completed(@span.span_id, 1_234)

      assert end_time == 1_234

      # update no longer affects this span (status is :completed) —
      # select_replace's match-spec only matches :active rows.
      Otel.Trace.SpanStorage.update(%{@span | name: "noop"})
      assert Otel.Trace.SpanStorage.get(@span.span_id) == nil

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

      Otel.Trace.SpanStorage.insert(active)
      Otel.Trace.SpanStorage.insert(will_complete)
      Otel.Trace.SpanStorage.mark_completed(2, 500)

      assert [%Otel.Trace.Span{span_id: 2}] = Otel.Trace.SpanStorage.take_completed(10)
      assert %Otel.Trace.Span{} = Otel.Trace.SpanStorage.get(1)
    end
  end

  test "ETS table is named, public, and write-concurrent" do
    info = :ets.info(Otel.Trace.SpanStorage)

    assert info[:named_table] == true
    assert info[:protection] == :public
    assert info[:write_concurrency] != false
  end
end
