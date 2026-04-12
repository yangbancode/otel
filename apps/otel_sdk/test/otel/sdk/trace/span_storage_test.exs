defmodule Otel.SDK.Trace.SpanStorageTest do
  use ExUnit.Case

  setup do
    pid =
      case Otel.SDK.Trace.SpanStorage.start_link() do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    :ets.delete_all_objects(Otel.SDK.Trace.SpanStorage.table_name())
    %{storage: pid}
  end

  @span %Otel.SDK.Trace.Span{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    name: "test_span",
    kind: :internal,
    start_time: System.system_time(:nanosecond),
    is_recording: true
  }

  describe "insert/1" do
    test "inserts a span" do
      assert Otel.SDK.Trace.SpanStorage.insert(@span) == true
    end
  end

  describe "get/1" do
    test "returns span by span_id" do
      Otel.SDK.Trace.SpanStorage.insert(@span)
      span = Otel.SDK.Trace.SpanStorage.get(@span.span_id)
      assert span.name == "test_span"
      assert span.trace_id == @span.trace_id
    end

    test "returns nil for missing span_id" do
      assert Otel.SDK.Trace.SpanStorage.get(999) == nil
    end
  end

  describe "take/1" do
    test "removes and returns span" do
      Otel.SDK.Trace.SpanStorage.insert(@span)
      span = Otel.SDK.Trace.SpanStorage.take(@span.span_id)
      assert span.name == "test_span"
      # gone from table
      assert Otel.SDK.Trace.SpanStorage.get(@span.span_id) == nil
    end

    test "returns nil for missing span_id" do
      assert Otel.SDK.Trace.SpanStorage.take(999) == nil
    end
  end

  describe "insert as update" do
    test "re-insert replaces span" do
      Otel.SDK.Trace.SpanStorage.insert(@span)
      updated_span = %{@span | name: "updated_name"}
      Otel.SDK.Trace.SpanStorage.insert(updated_span)
      span = Otel.SDK.Trace.SpanStorage.get(@span.span_id)
      assert span.name == "updated_name"
    end
  end

  describe "table properties" do
    test "table is public and named" do
      info = :ets.info(Otel.SDK.Trace.SpanStorage.table_name())
      assert info[:named_table] == true
      assert info[:protection] == :public
    end

    test "table has write_concurrency" do
      info = :ets.info(Otel.SDK.Trace.SpanStorage.table_name())
      assert info[:write_concurrency] != false
    end
  end
end
