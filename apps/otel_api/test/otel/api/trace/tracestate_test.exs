defmodule Otel.API.Trace.TraceStateTest do
  use ExUnit.Case, async: true

  describe "new/0" do
    test "creates empty tracestate" do
      ts = %Otel.API.Trace.TraceState{}
      assert ts.members == []
    end
  end

  describe "new/1" do
    test "creates tracestate from valid pairs" do
      ts = Otel.API.Trace.TraceState.new([{"vendor", "value"}, {"other", "data"}])
      assert ts.members == [{"vendor", "value"}, {"other", "data"}]
    end

    test "accepts all valid entries without truncation" do
      # new/1 does not enforce the 32-member cap (W3C § 3.3.3 MUST applies
      # only to decoders; callers building state directly accept the
      # invariant responsibility).
      pairs = for i <- 1..40, do: {"key#{i}", "val#{i}"}
      ts = Otel.API.Trace.TraceState.new(pairs)
      assert length(ts.members) == 40
    end
  end

  describe "get/2" do
    test "returns value for existing key" do
      ts = Otel.API.Trace.TraceState.new([{"vendor", "value"}])
      assert Otel.API.Trace.TraceState.get(ts, "vendor") == "value"
    end

    test "returns empty string for missing key" do
      ts = %Otel.API.Trace.TraceState{}
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
      assert Otel.API.Trace.TraceState.encode(%Otel.API.Trace.TraceState{}) == ""
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
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "vendor", "val")
      assert Otel.API.Trace.TraceState.get(ts, "vendor") == "val"
    end

    test "accepts key with allowed chars" do
      ts =
        Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "my-vendor_key/1*2", "val")

      assert Otel.API.Trace.TraceState.get(ts, "my-vendor_key/1*2") == "val"
    end

    test "accepts multi-tenant key" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "1tenant@vendor", "val")
      assert Otel.API.Trace.TraceState.get(ts, "1tenant@vendor") == "val"
    end
  end

  describe "invalid key rejection (W3C § 3.3.1.1)" do
    test "rejects uppercase-starting key" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "Vendor", "val")
      assert ts.members == []
    end

    test "rejects simple key starting with digit" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "1vendor", "val")
      assert ts.members == []
    end

    test "rejects key with disallowed char" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "vendor!", "val")
      assert ts.members == []
    end

    test "update on invalid key leaves state unchanged" do
      ts = Otel.API.Trace.TraceState.new([{"a", "1"}])
      result = Otel.API.Trace.TraceState.update(ts, "BAD", "v")
      assert result == ts
    end
  end

  describe "invalid value rejection (W3C § 3.3.1.1)" do
    test "rejects value with `,`" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "k", "a,b")
      assert ts.members == []
    end

    test "rejects value with `=`" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "k", "a=b")
      assert ts.members == []
    end

    test "rejects value ending in space" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "k", "trailing ")
      assert ts.members == []
    end

    test "accepts value with internal spaces" do
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "k", "a b c")
      assert Otel.API.Trace.TraceState.get(ts, "k") == "a b c"
    end

    test "accepts value at exactly 256 chars (W3C § 3.3.2 max)" do
      at_limit = String.duplicate("x", 256)
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "k", at_limit)
      assert Otel.API.Trace.TraceState.get(ts, "k") == at_limit
    end

    test "rejects value longer than 256 chars (W3C § 3.3.2 max)" do
      over_limit = String.duplicate("x", 257)
      ts = Otel.API.Trace.TraceState.add(%Otel.API.Trace.TraceState{}, "k", over_limit)
      assert ts.members == []
    end
  end

  describe "decode rejects oversized header (W3C § 3.3.3)" do
    test "returns empty state when header exceeds 512 bytes" do
      oversized = 1..100 |> Enum.map_join(",", fn i -> "k#{i}=v#{i}" end)
      assert byte_size(oversized) > 512
      assert %Otel.API.Trace.TraceState{members: []} = Otel.API.Trace.TraceState.decode(oversized)
    end

    test "accepts header at or below 512 bytes" do
      under_limit = String.duplicate("ab,", 50) |> String.trim_trailing(",")
      assert byte_size(under_limit) < 512
      # All entries are malformed (no =), so members stays empty but decode doesn't crash
      result = Otel.API.Trace.TraceState.decode(under_limit)
      assert %Otel.API.Trace.TraceState{} = result
    end

    test "accepts header with exactly 32 list-members (W3C § 3.3.3 boundary)" do
      header = 1..32 |> Enum.map_join(",", fn i -> "k#{i}=v#{i}" end)
      ts = Otel.API.Trace.TraceState.decode(header)
      assert Otel.API.Trace.TraceState.size(ts) == 32
    end

    test "discards whole tracestate when header has more than 32 list-members" do
      # Spec: "If the tracestate value has more than 32 list-members, the
      # parser MUST discard the whole tracestate."
      header = 1..33 |> Enum.map_join(",", fn i -> "k#{i}=v#{i}" end)
      assert byte_size(header) < 512
      assert %Otel.API.Trace.TraceState{members: []} = Otel.API.Trace.TraceState.decode(header)
    end
  end

  describe "decode drops malformed entries" do
    test "drops entries without `=`" do
      ts = Otel.API.Trace.TraceState.decode("valid=ok,broken,also=fine")
      assert Otel.API.Trace.TraceState.get(ts, "valid") == "ok"
      assert Otel.API.Trace.TraceState.get(ts, "also") == "fine"
      assert Otel.API.Trace.TraceState.size(ts) == 2
    end

    test "drops entries with invalid key" do
      ts = Otel.API.Trace.TraceState.decode("BAD=v,good=ok")
      assert Otel.API.Trace.TraceState.size(ts) == 1
      assert Otel.API.Trace.TraceState.get(ts, "good") == "ok"
    end
  end

  describe "valid_key?/1" do
    test "accepts simple-key (lowercase alpha start)" do
      assert Otel.API.Trace.TraceState.valid_key?("vendor")
    end

    test "accepts simple-key with allowed symbols (_ - * /)" do
      assert Otel.API.Trace.TraceState.valid_key?("my-key_1*2/3")
    end

    test "accepts tenant@system multi-tenant key" do
      assert Otel.API.Trace.TraceState.valid_key?("tenant@system")
    end

    test "accepts multi-tenant with tenant-id starting with digit" do
      assert Otel.API.Trace.TraceState.valid_key?("1tenant@vendor")
    end

    test "rejects empty string" do
      refute Otel.API.Trace.TraceState.valid_key?("")
    end

    test "rejects uppercase" do
      refute Otel.API.Trace.TraceState.valid_key?("Vendor")
    end

    test "rejects simple-key starting with digit" do
      refute Otel.API.Trace.TraceState.valid_key?("1vendor")
    end

    test "rejects disallowed symbols" do
      refute Otel.API.Trace.TraceState.valid_key?("vendor!")
      refute Otel.API.Trace.TraceState.valid_key?("ven dor")
    end

    test "rejects simple-key longer than 256 chars" do
      refute Otel.API.Trace.TraceState.valid_key?("a" <> String.duplicate("x", 256))
    end

    test "rejects non-binary input" do
      refute Otel.API.Trace.TraceState.valid_key?(nil)
      refute Otel.API.Trace.TraceState.valid_key?(:atom)
      refute Otel.API.Trace.TraceState.valid_key?(123)
      refute Otel.API.Trace.TraceState.valid_key?([])
    end
  end

  describe "valid_value?/1" do
    test "accepts printable ASCII" do
      assert Otel.API.Trace.TraceState.valid_value?("hello")
      assert Otel.API.Trace.TraceState.valid_value?("abc123_XYZ")
    end

    test "accepts value with internal spaces" do
      assert Otel.API.Trace.TraceState.valid_value?("a b c")
    end

    test "accepts full range of allowed printable symbols" do
      assert Otel.API.Trace.TraceState.valid_value?("!\"#$%&'()*+-./:;<>?@[\\]^_`{|}~")
    end

    test "accepts value at exactly 256 chars" do
      assert Otel.API.Trace.TraceState.valid_value?(String.duplicate("x", 256))
    end

    test "rejects empty string" do
      refute Otel.API.Trace.TraceState.valid_value?("")
    end

    test "rejects value containing comma" do
      refute Otel.API.Trace.TraceState.valid_value?("a,b")
    end

    test "rejects value containing equals" do
      refute Otel.API.Trace.TraceState.valid_value?("a=b")
    end

    test "rejects value ending in space" do
      refute Otel.API.Trace.TraceState.valid_value?("trailing ")
    end

    test "rejects value longer than 256 chars" do
      refute Otel.API.Trace.TraceState.valid_value?(String.duplicate("x", 257))
    end

    test "rejects non-ASCII characters (UTF-8 safety)" do
      refute Otel.API.Trace.TraceState.valid_value?("한글")
      refute Otel.API.Trace.TraceState.valid_value?("café")
      refute Otel.API.Trace.TraceState.valid_value?("emoji🎉")
    end

    test "rejects control characters" do
      refute Otel.API.Trace.TraceState.valid_value?("line\nbreak")
      refute Otel.API.Trace.TraceState.valid_value?("tab\there")
      refute Otel.API.Trace.TraceState.valid_value?("null\0byte")
    end

    test "rejects non-binary input" do
      refute Otel.API.Trace.TraceState.valid_value?(nil)
      refute Otel.API.Trace.TraceState.valid_value?(:atom)
      refute Otel.API.Trace.TraceState.valid_value?(123)
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
