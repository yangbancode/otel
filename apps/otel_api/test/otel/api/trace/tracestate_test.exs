defmodule Otel.API.Trace.TraceStateTest do
  use ExUnit.Case, async: true

  alias Otel.API.Trace.TraceState

  describe "new/0" do
    test "creates empty tracestate" do
      ts = TraceState.new()
      assert ts.members == []
    end
  end

  describe "new/1" do
    test "creates tracestate from valid pairs" do
      ts = TraceState.new([{"vendor", "value"}, {"other", "data"}])
      assert ts.members == [{"vendor", "value"}, {"other", "data"}]
    end

    test "drops invalid keys" do
      ts = TraceState.new([{"INVALID", "value"}, {"valid", "data"}])
      assert ts.members == [{"valid", "data"}]
    end

    test "drops invalid values" do
      # value with trailing space is invalid
      ts = TraceState.new([{"key", "bad "}, {"valid", "data"}])
      assert ts.members == [{"valid", "data"}]
    end

    test "limits to 32 members" do
      pairs = for i <- 1..40, do: {"key#{i}", "val#{i}"}
      ts = TraceState.new(pairs)
      assert length(ts.members) == 32
    end
  end

  describe "get/2" do
    test "returns value for existing key" do
      ts = TraceState.new([{"vendor", "value"}])
      assert TraceState.get(ts, "vendor") == "value"
    end

    test "returns empty string for missing key" do
      ts = TraceState.new()
      assert TraceState.get(ts, "missing") == ""
    end
  end

  describe "put/3" do
    test "adds new key/value pair to front" do
      ts = TraceState.new([{"existing", "data"}])
      ts = TraceState.put(ts, "new", "value")
      assert ts.members == [{"new", "value"}, {"existing", "data"}]
    end

    test "updates existing key and moves to front" do
      ts = TraceState.new([{"a", "1"}, {"b", "2"}, {"c", "3"}])
      ts = TraceState.put(ts, "b", "updated")
      assert ts.members == [{"b", "updated"}, {"a", "1"}, {"c", "3"}]
    end

    test "returns unchanged on invalid key" do
      ts = TraceState.new([{"valid", "data"}])
      ts2 = TraceState.put(ts, "INVALID", "value")
      assert ts2 == ts
    end

    test "returns unchanged on invalid value" do
      ts = TraceState.new([{"valid", "data"}])
      ts2 = TraceState.put(ts, "key", "")
      assert ts2 == ts
    end

    test "enforces max 32 members on put" do
      pairs = for i <- 1..32, do: {"key#{i}", "val#{i}"}
      ts = TraceState.new(pairs)
      ts = TraceState.put(ts, "extra", "value")
      assert length(ts.members) == 32
      assert TraceState.get(ts, "extra") == "value"
    end
  end

  describe "delete/2" do
    test "removes existing key" do
      ts = TraceState.new([{"a", "1"}, {"b", "2"}])
      ts = TraceState.delete(ts, "a")
      assert ts.members == [{"b", "2"}]
    end

    test "is no-op for missing key" do
      ts = TraceState.new([{"a", "1"}])
      ts2 = TraceState.delete(ts, "missing")
      assert ts2.members == [{"a", "1"}]
    end
  end

  describe "encode/1" do
    test "encodes to header string" do
      ts = TraceState.new([{"congo", "t61rcWkgMzE"}, {"rojo", "00f067aa0ba902b7"}])
      assert TraceState.encode(ts) == "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"
    end

    test "returns empty string for empty tracestate" do
      assert TraceState.encode(TraceState.new()) == ""
    end
  end

  describe "decode/1" do
    test "decodes valid header" do
      ts = TraceState.decode("congo=t61rcWkgMzE,rojo=00f067aa0ba902b7")
      assert ts.members == [{"congo", "t61rcWkgMzE"}, {"rojo", "00f067aa0ba902b7"}]
    end

    test "handles whitespace around entries" do
      ts = TraceState.decode(" congo=t61rcWkgMzE , rojo=00f067aa0ba902b7 ")
      assert ts.members == [{"congo", "t61rcWkgMzE"}, {"rojo", "00f067aa0ba902b7"}]
    end

    test "returns empty on invalid entry" do
      ts = TraceState.decode("valid=ok,INVALID=bad")
      assert ts.members == []
    end

    test "returns empty on malformed pair" do
      ts = TraceState.decode("noequals")
      assert ts.members == []
    end

    test "returns empty on empty value" do
      ts = TraceState.decode("key=")
      assert ts.members == []
    end

    test "limits to 32 members" do
      header = Enum.map_join(1..40, ",", fn i -> "key#{i}=val#{i}" end)
      ts = TraceState.decode(header)
      assert length(ts.members) == 32
    end

    test "deduplicates keys keeping last occurrence" do
      ts = TraceState.decode("key=first,key=second")
      assert ts.members == [{"key", "second"}]
    end
  end

  describe "key validation" do
    test "accepts simple key" do
      ts = TraceState.put(TraceState.new(), "vendor", "val")
      assert TraceState.get(ts, "vendor") == "val"
    end

    test "accepts key with allowed chars" do
      ts = TraceState.put(TraceState.new(), "my-vendor_key/1*2", "val")
      assert TraceState.get(ts, "my-vendor_key/1*2") == "val"
    end

    test "accepts multi-tenant key" do
      ts = TraceState.put(TraceState.new(), "1tenant@vendor", "val")
      assert TraceState.get(ts, "1tenant@vendor") == "val"
    end

    test "rejects uppercase key" do
      ts = TraceState.put(TraceState.new(), "Vendor", "val")
      assert ts.members == []
    end

    test "rejects empty key" do
      ts = TraceState.put(TraceState.new(), "", "val")
      assert ts.members == []
    end

    test "rejects non-binary key" do
      ts = TraceState.put(TraceState.new(), :atom_key, "val")
      assert ts.members == []
    end

    test "rejects non-binary value" do
      ts = TraceState.put(TraceState.new(), "key", 123)
      assert ts.members == []
    end
  end

  describe "immutability" do
    test "put returns new tracestate" do
      ts1 = TraceState.new([{"a", "1"}])
      ts2 = TraceState.put(ts1, "b", "2")
      assert ts1.members == [{"a", "1"}]
      assert ts2.members == [{"b", "2"}, {"a", "1"}]
    end

    test "delete returns new tracestate" do
      ts1 = TraceState.new([{"a", "1"}, {"b", "2"}])
      ts2 = TraceState.delete(ts1, "a")
      assert ts1.members == [{"a", "1"}, {"b", "2"}]
      assert ts2.members == [{"b", "2"}]
    end
  end
end
