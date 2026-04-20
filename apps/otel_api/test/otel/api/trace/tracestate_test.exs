defmodule Otel.API.Trace.TraceStateTest do
  use ExUnit.Case, async: true

  alias Otel.API.Trace.TraceState

  describe "empty state" do
    test "default struct is empty" do
      assert TraceState.size(%TraceState{}) == 0
      assert TraceState.encode(%TraceState{}) == ""
    end
  end

  describe "get/2" do
    test "returns value for existing key" do
      ts = %TraceState{} |> TraceState.add("vendor", "value")
      assert TraceState.get(ts, "vendor") == "value"
    end

    test "returns empty string for missing key" do
      assert TraceState.get(%TraceState{}, "missing") == ""
    end
  end

  describe "add/3" do
    test "adds new key/value pair to front" do
      ts =
        %TraceState{}
        |> TraceState.add("existing", "data")
        |> TraceState.add("new", "value")

      assert TraceState.encode(ts) == "new=value,existing=data"
    end

    test "returns unchanged when at max 32 members" do
      ts =
        Enum.reduce(1..32, %TraceState{}, fn i, acc ->
          TraceState.add(acc, "key#{i}", "val#{i}")
        end)

      ts2 = TraceState.add(ts, "extra", "value")
      assert TraceState.size(ts2) == 32
      assert TraceState.get(ts2, "extra") == ""
    end
  end

  describe "update/3" do
    test "updates existing key and moves to front" do
      ts =
        %TraceState{}
        |> TraceState.add("c", "3")
        |> TraceState.add("b", "2")
        |> TraceState.add("a", "1")

      ts = TraceState.update(ts, "b", "updated")
      assert TraceState.encode(ts) == "b=updated,a=1,c=3"
    end
  end

  describe "delete/2" do
    test "removes existing key" do
      ts =
        %TraceState{}
        |> TraceState.add("b", "2")
        |> TraceState.add("a", "1")

      ts = TraceState.delete(ts, "a")
      assert TraceState.encode(ts) == "b=2"
    end

    test "is no-op for missing key" do
      ts = %TraceState{} |> TraceState.add("a", "1")
      ts2 = TraceState.delete(ts, "missing")
      assert TraceState.encode(ts2) == "a=1"
    end
  end

  describe "encode/1" do
    test "encodes to header string" do
      ts =
        %TraceState{}
        |> TraceState.add("rojo", "00f067aa0ba902b7")
        |> TraceState.add("congo", "t61rcWkgMzE")

      assert TraceState.encode(ts) == "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"
    end

    test "returns empty string for empty tracestate" do
      assert TraceState.encode(%TraceState{}) == ""
    end
  end

  describe "decode/1" do
    test "decodes valid header" do
      ts = TraceState.decode("congo=t61rcWkgMzE,rojo=00f067aa0ba902b7")
      assert TraceState.get(ts, "congo") == "t61rcWkgMzE"
      assert TraceState.get(ts, "rojo") == "00f067aa0ba902b7"
      assert TraceState.encode(ts) == "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"
    end

    test "handles whitespace around entries" do
      ts = TraceState.decode(" congo=t61rcWkgMzE , rojo=00f067aa0ba902b7 ")
      assert TraceState.encode(ts) == "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"
    end

    test "deduplicates keys keeping last occurrence" do
      ts = TraceState.decode("key=first,key=second")
      assert TraceState.get(ts, "key") == "second"
      assert TraceState.size(ts) == 1
    end
  end

  describe "key validation via add/3" do
    test "accepts simple key" do
      ts = %TraceState{} |> TraceState.add("vendor", "val")
      assert TraceState.get(ts, "vendor") == "val"
    end

    test "accepts key with allowed chars" do
      ts = %TraceState{} |> TraceState.add("my-vendor_key/1*2", "val")
      assert TraceState.get(ts, "my-vendor_key/1*2") == "val"
    end

    test "accepts multi-tenant key" do
      ts = %TraceState{} |> TraceState.add("1tenant@vendor", "val")
      assert TraceState.get(ts, "1tenant@vendor") == "val"
    end
  end

  describe "invalid key rejection (W3C §3.3.1.3.1)" do
    test "rejects uppercase-starting key" do
      ts = %TraceState{} |> TraceState.add("Vendor", "val")
      assert TraceState.size(ts) == 0
    end

    test "rejects key with disallowed char" do
      ts = %TraceState{} |> TraceState.add("vendor!", "val")
      assert TraceState.size(ts) == 0
    end

    test "update on invalid key leaves state unchanged" do
      ts = %TraceState{} |> TraceState.add("a", "1")
      before = TraceState.encode(ts)
      result = TraceState.update(ts, "BAD", "v")
      assert TraceState.encode(result) == before
    end
  end

  describe "invalid value rejection (W3C §3.3.1.3.2)" do
    test "rejects value with `,`" do
      ts = %TraceState{} |> TraceState.add("k", "a,b")
      assert TraceState.size(ts) == 0
    end

    test "rejects value with `=`" do
      ts = %TraceState{} |> TraceState.add("k", "a=b")
      assert TraceState.size(ts) == 0
    end

    test "rejects value ending in space" do
      ts = %TraceState{} |> TraceState.add("k", "trailing ")
      assert TraceState.size(ts) == 0
    end

    test "accepts value with internal spaces" do
      ts = %TraceState{} |> TraceState.add("k", "a b c")
      assert TraceState.get(ts, "k") == "a b c"
    end

    test "accepts value at exactly 256 chars (W3C §3.3.1.3.2 max)" do
      at_limit = String.duplicate("x", 256)
      ts = %TraceState{} |> TraceState.add("k", at_limit)
      assert TraceState.get(ts, "k") == at_limit
    end

    test "rejects value longer than 256 chars (W3C §3.3.1.3.2 max)" do
      over_limit = String.duplicate("x", 257)
      ts = %TraceState{} |> TraceState.add("k", over_limit)
      assert TraceState.size(ts) == 0
    end
  end

  describe "decode rejects oversized header (W3C §3.3.1.5)" do
    test "returns empty state when header exceeds 512 bytes" do
      oversized = 1..100 |> Enum.map_join(",", fn i -> "k#{i}=v#{i}" end)
      assert byte_size(oversized) > 512
      assert TraceState.size(TraceState.decode(oversized)) == 0
    end

    test "accepts header at or below 512 bytes" do
      under_limit = String.duplicate("ab,", 50) |> String.trim_trailing(",")
      assert byte_size(under_limit) < 512
      # All entries are malformed (no =), so state stays empty but decode doesn't crash
      assert TraceState.size(TraceState.decode(under_limit)) == 0
    end

    test "accepts header with exactly 32 list-members (W3C § 3.3.3 boundary)" do
      header = 1..32 |> Enum.map_join(",", fn i -> "k#{i}=v#{i}" end)
      ts = TraceState.decode(header)
      assert TraceState.size(ts) == 32
    end

    test "discards whole tracestate when header has more than 32 list-members" do
      # W3C §3.3.1.1 sets the 32-member limit but does not define
      # parser behaviour when exceeded. We reject the whole header,
      # matching `opentelemetry-erlang`'s `otel_tracestate:decode_header/1`.
      header = 1..33 |> Enum.map_join(",", fn i -> "k#{i}=v#{i}" end)
      assert byte_size(header) < 512
      assert TraceState.size(TraceState.decode(header)) == 0
    end
  end

  describe "decode drops malformed entries" do
    test "drops entries without `=`" do
      ts = TraceState.decode("valid=ok,broken,also=fine")
      assert TraceState.get(ts, "valid") == "ok"
      assert TraceState.get(ts, "also") == "fine"
      assert TraceState.size(ts) == 2
    end

    test "drops entries with invalid key" do
      ts = TraceState.decode("BAD=v,good=ok")
      assert TraceState.size(ts) == 1
      assert TraceState.get(ts, "good") == "ok"
    end
  end

  describe "valid_key?/1" do
    test "accepts simple-key (lowercase alpha start)" do
      assert TraceState.valid_key?("vendor")
    end

    test "accepts key with allowed symbols (_ - * / @)" do
      assert TraceState.valid_key?("my-key_1*2/3@system")
    end

    test "accepts key starting with digit (Level 2)" do
      assert TraceState.valid_key?("1vendor")
    end

    test "accepts tenant@system style key" do
      assert TraceState.valid_key?("tenant@system")
      assert TraceState.valid_key?("1tenant@vendor")
    end

    test "accepts key with multiple @ (Level 2 grammar)" do
      assert TraceState.valid_key?("a@b@c")
    end

    test "rejects empty string" do
      refute TraceState.valid_key?("")
    end

    test "rejects uppercase" do
      refute TraceState.valid_key?("Vendor")
    end

    test "rejects disallowed symbols" do
      refute TraceState.valid_key?("vendor!")
      refute TraceState.valid_key?("ven dor")
    end

    test "rejects key longer than 256 chars" do
      refute TraceState.valid_key?("a" <> String.duplicate("x", 256))
    end

    test "rejects non-binary input" do
      refute TraceState.valid_key?(nil)
      refute TraceState.valid_key?(:atom)
      refute TraceState.valid_key?(123)
      refute TraceState.valid_key?([])
    end
  end

  describe "valid_value?/1" do
    test "accepts printable ASCII" do
      assert TraceState.valid_value?("hello")
      assert TraceState.valid_value?("abc123_XYZ")
    end

    test "accepts value with internal spaces" do
      assert TraceState.valid_value?("a b c")
    end

    test "accepts full range of allowed printable symbols" do
      assert TraceState.valid_value?("!\"#$%&'()*+-./:;<>?@[\\]^_`{|}~")
    end

    test "accepts value at exactly 256 chars" do
      assert TraceState.valid_value?(String.duplicate("x", 256))
    end

    test "rejects empty string" do
      refute TraceState.valid_value?("")
    end

    test "rejects value containing comma" do
      refute TraceState.valid_value?("a,b")
    end

    test "rejects value containing equals" do
      refute TraceState.valid_value?("a=b")
    end

    test "rejects value ending in space" do
      refute TraceState.valid_value?("trailing ")
    end

    test "rejects value longer than 256 chars" do
      refute TraceState.valid_value?(String.duplicate("x", 257))
    end

    test "rejects non-ASCII characters (UTF-8 safety)" do
      refute TraceState.valid_value?("한글")
      refute TraceState.valid_value?("café")
      refute TraceState.valid_value?("emoji🎉")
    end

    test "rejects control characters" do
      refute TraceState.valid_value?("line\nbreak")
      refute TraceState.valid_value?("tab\there")
      refute TraceState.valid_value?("null\0byte")
    end

    test "rejects non-binary input" do
      refute TraceState.valid_value?(nil)
      refute TraceState.valid_value?(:atom)
      refute TraceState.valid_value?(123)
    end
  end

  describe "immutability" do
    test "add returns new tracestate" do
      ts1 = %TraceState{} |> TraceState.add("a", "1")
      ts2 = TraceState.add(ts1, "b", "2")
      assert TraceState.encode(ts1) == "a=1"
      assert TraceState.encode(ts2) == "b=2,a=1"
    end

    test "delete returns new tracestate" do
      ts1 =
        %TraceState{}
        |> TraceState.add("b", "2")
        |> TraceState.add("a", "1")

      ts2 = TraceState.delete(ts1, "a")
      assert TraceState.encode(ts1) == "a=1,b=2"
      assert TraceState.encode(ts2) == "b=2"
    end
  end
end
