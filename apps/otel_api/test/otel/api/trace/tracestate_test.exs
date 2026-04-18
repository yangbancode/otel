defmodule Otel.API.Trace.TraceStateTest do
  use ExUnit.Case, async: true

  describe "new/0" do
    test "creates empty tracestate" do
      ts = Otel.API.Trace.TraceState.new()
      assert ts.members == []
    end
  end

  describe "new/1" do
    test "creates tracestate from valid pairs" do
      ts = Otel.API.Trace.TraceState.new([{"vendor", "value"}, {"other", "data"}])
      assert ts.members == [{"vendor", "value"}, {"other", "data"}]
    end

    test "limits to 32 members" do
      pairs = for i <- 1..40, do: {"key#{i}", "val#{i}"}
      ts = Otel.API.Trace.TraceState.new(pairs)
      assert length(ts.members) == 32
    end
  end

  describe "get/2" do
    test "returns value for existing key" do
      ts = Otel.API.Trace.TraceState.new([{"vendor", "value"}])
      assert Otel.API.Trace.TraceState.get(ts, "vendor") == "value"
    end

    test "returns empty string for missing key" do
      ts = Otel.API.Trace.TraceState.new()
      assert Otel.API.Trace.TraceState.get(ts, "missing") == ""
    end
  end

  describe "add/3" do
    test "adds new key/value pair to front" do
      ts = Otel.API.Trace.TraceState.new([{"existing", "data"}])
      ts = Otel.API.Trace.TraceState.add(ts, "new", "value")
      assert ts.members == [{"new", "value"}, {"existing", "data"}]
    end

    test "returns unchanged when at max 32 members" do
      pairs = for i <- 1..32, do: {"key#{i}", "val#{i}"}
      ts = Otel.API.Trace.TraceState.new(pairs)
      ts2 = Otel.API.Trace.TraceState.add(ts, "extra", "value")
      assert length(ts2.members) == 32
      assert Otel.API.Trace.TraceState.get(ts2, "extra") == ""
    end
  end

  describe "update/3" do
    test "updates existing key and moves to front" do
      ts = Otel.API.Trace.TraceState.new([{"a", "1"}, {"b", "2"}, {"c", "3"}])
      ts = Otel.API.Trace.TraceState.update(ts, "b", "updated")
      assert ts.members == [{"b", "updated"}, {"a", "1"}, {"c", "3"}]
    end
  end

  describe "delete/2" do
    test "removes existing key" do
      ts = Otel.API.Trace.TraceState.new([{"a", "1"}, {"b", "2"}])
      ts = Otel.API.Trace.TraceState.delete(ts, "a")
      assert ts.members == [{"b", "2"}]
    end

    test "is no-op for missing key" do
      ts = Otel.API.Trace.TraceState.new([{"a", "1"}])
      ts2 = Otel.API.Trace.TraceState.delete(ts, "missing")
      assert ts2.members == [{"a", "1"}]
    end
  end

  describe "encode/1" do
    test "encodes to header string" do
      ts = Otel.API.Trace.TraceState.new([{"congo", "t61rcWkgMzE"}, {"rojo", "00f067aa0ba902b7"}])
      assert Otel.API.Trace.TraceState.encode(ts) == "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"
    end

    test "returns empty string for empty tracestate" do
      assert Otel.API.Trace.TraceState.encode(Otel.API.Trace.TraceState.new()) == ""
    end
  end

  describe "decode/1" do
    test "decodes valid header" do
      ts = Otel.API.Trace.TraceState.decode("congo=t61rcWkgMzE,rojo=00f067aa0ba902b7")
      assert ts.members == [{"congo", "t61rcWkgMzE"}, {"rojo", "00f067aa0ba902b7"}]
    end

    test "handles whitespace around entries" do
      ts = Otel.API.Trace.TraceState.decode(" congo=t61rcWkgMzE , rojo=00f067aa0ba902b7 ")
      assert ts.members == [{"congo", "t61rcWkgMzE"}, {"rojo", "00f067aa0ba902b7"}]
    end

    test "deduplicates keys keeping last occurrence" do
      ts = Otel.API.Trace.TraceState.decode("key=first,key=second")
      assert ts.members == [{"key", "second"}]
    end
  end

  describe "key validation" do
    test "accepts simple key" do
      ts = Otel.API.Trace.TraceState.add(Otel.API.Trace.TraceState.new(), "vendor", "val")
      assert Otel.API.Trace.TraceState.get(ts, "vendor") == "val"
    end

    test "accepts key with allowed chars" do
      ts =
        Otel.API.Trace.TraceState.add(Otel.API.Trace.TraceState.new(), "my-vendor_key/1*2", "val")

      assert Otel.API.Trace.TraceState.get(ts, "my-vendor_key/1*2") == "val"
    end

    test "accepts multi-tenant key" do
      ts = Otel.API.Trace.TraceState.add(Otel.API.Trace.TraceState.new(), "1tenant@vendor", "val")
      assert Otel.API.Trace.TraceState.get(ts, "1tenant@vendor") == "val"
    end
  end

  describe "immutability" do
    test "add returns new tracestate" do
      ts1 = Otel.API.Trace.TraceState.new([{"a", "1"}])
      ts2 = Otel.API.Trace.TraceState.add(ts1, "b", "2")
      assert ts1.members == [{"a", "1"}]
      assert ts2.members == [{"b", "2"}, {"a", "1"}]
    end

    test "delete returns new tracestate" do
      ts1 = Otel.API.Trace.TraceState.new([{"a", "1"}, {"b", "2"}])
      ts2 = Otel.API.Trace.TraceState.delete(ts1, "a")
      assert ts1.members == [{"a", "1"}, {"b", "2"}]
      assert ts2.members == [{"b", "2"}]
    end
  end
end
