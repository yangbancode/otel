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

  describe "complete/1 + take_completed/1" do
    test "complete flips status; take_completed yields it once" do
      Otel.Trace.SpanStorage.insert(@span)
      ended = %{@span | end_time: 1_234}
      assert :ok = Otel.Trace.SpanStorage.complete(ended)

      # update no longer affects this span (status is :completed) —
      # select_replace's match-spec only matches :active rows.
      Otel.Trace.SpanStorage.update(%{@span | name: "noop"})
      assert Otel.Trace.SpanStorage.get(@span.span_id) == nil

      # take_completed returns the span as written by complete —
      # caller-provided end_time is on the struct directly.
      assert [%Otel.Trace.Span{span_id: sid, name: "test_span", end_time: 1_234}] =
               Otel.Trace.SpanStorage.take_completed(10)

      assert sid == @span.span_id

      # Subsequent take returns empty (already taken + deleted).
      assert [] = Otel.Trace.SpanStorage.take_completed(10)
    end

    test "complete on missing span → :ok (silent no-op)" do
      assert :ok = Otel.Trace.SpanStorage.complete(%{@span | span_id: 999, end_time: 1_000})
    end

    test "take_completed only returns :completed, leaves :active alone" do
      active = %{@span | span_id: 1}
      will_complete = %{@span | span_id: 2, end_time: 500}

      Otel.Trace.SpanStorage.insert(active)
      Otel.Trace.SpanStorage.insert(will_complete)
      Otel.Trace.SpanStorage.complete(will_complete)

      assert [%Otel.Trace.Span{span_id: 2, end_time: 500}] =
               Otel.Trace.SpanStorage.take_completed(10)

      assert %Otel.Trace.Span{} = Otel.Trace.SpanStorage.get(1)
    end
  end

  describe "sweep stale :active spans" do
    # `Otel.Trace.Span.start_time` is in nanoseconds (OTLP wire
    # format), and the sweep TTL constant is 30 minutes. These
    # tests force-age a span by writing a `start_time` older than
    # the cutoff, then trigger the sweep manually via the GenServer
    # message and synchronize with `:sys.get_state/1`.
    @ttl_minutes 30
    @older_than_ttl_ns System.system_time(:nanosecond) -
                         (@ttl_minutes + 1) * 60 * 1_000 * 1_000_000

    test "removes :active spans older than the TTL" do
      stale = %{@span | start_time: @older_than_ttl_ns}
      Otel.Trace.SpanStorage.insert(stale)

      send(Otel.Trace.SpanStorage, :sweep)
      :sys.get_state(Otel.Trace.SpanStorage)

      assert Otel.Trace.SpanStorage.get(stale.span_id) == nil
    end

    test "keeps :active spans within the TTL" do
      Otel.Trace.SpanStorage.insert(@span)

      send(Otel.Trace.SpanStorage, :sweep)
      :sys.get_state(Otel.Trace.SpanStorage)

      assert %Otel.Trace.Span{} = Otel.Trace.SpanStorage.get(@span.span_id)
    end

    test "does not touch :completed rows even with old start_time" do
      stale_then_completed = %{
        @span
        | start_time: @older_than_ttl_ns,
          end_time: @older_than_ttl_ns + 1_000
      }

      Otel.Trace.SpanStorage.insert(stale_then_completed)
      Otel.Trace.SpanStorage.complete(stale_then_completed)

      send(Otel.Trace.SpanStorage, :sweep)
      :sys.get_state(Otel.Trace.SpanStorage)

      assert [%Otel.Trace.Span{}] = Otel.Trace.SpanStorage.take_completed(10)
    end
  end

  test "ETS table is named, public, and write-concurrent" do
    info = :ets.info(Otel.Trace.SpanStorage)

    assert info[:named_table] == true
    assert info[:protection] == :public
    assert info[:write_concurrency] != false
  end
end
