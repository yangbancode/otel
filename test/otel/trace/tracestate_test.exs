defmodule Otel.Trace.TraceStateTest do
  use ExUnit.Case, async: true

  describe "empty state" do
    test "default struct is empty and encodes to \"\"" do
      assert Otel.Trace.TraceState.empty?(%Otel.Trace.TraceState{})
      assert Otel.Trace.TraceState.encode(%Otel.Trace.TraceState{}) == ""
    end
  end

  describe "get/2" do
    test "returns the value for an existing key, \"\" for a missing one" do
      ts = Otel.Trace.TraceState.add(%Otel.Trace.TraceState{}, "vendor", "value")

      assert Otel.Trace.TraceState.get(ts, "vendor") == "value"
      assert Otel.Trace.TraceState.get(ts, "missing") == ""
    end
  end

  describe "add/3" do
    test "prepends new entries (left-most = newest)" do
      ts =
        %Otel.Trace.TraceState{}
        |> Otel.Trace.TraceState.add("existing", "data")
        |> Otel.Trace.TraceState.add("new", "value")

      assert Otel.Trace.TraceState.encode(ts) == "new=value,existing=data"
    end

    # Spec W3C §3.5: "MUST NOT result in the same key being present multiple times".
    test "rejects a duplicate key (preserves the first value)" do
      ts =
        %Otel.Trace.TraceState{}
        |> Otel.Trace.TraceState.add("vendor", "first")
        |> Otel.Trace.TraceState.add("vendor", "second")

      assert Otel.Trace.TraceState.get(ts, "vendor") == "first"
    end

    # Spec W3C §3.3.1.1: max 32 list-members; right-most is dropped.
    test "drops the right-most (oldest) entry when at the 32-member cap" do
      ts =
        Enum.reduce(1..32, %Otel.Trace.TraceState{}, fn i, acc ->
          Otel.Trace.TraceState.add(acc, "key#{i}", "val#{i}")
        end)
        |> Otel.Trace.TraceState.add("extra", "value")

      assert Otel.Trace.TraceState.get(ts, "extra") == "value"
      # Right-most (oldest = "key1") dropped; second-oldest retained.
      assert Otel.Trace.TraceState.get(ts, "key1") == ""
      assert Otel.Trace.TraceState.get(ts, "key2") == "val2"
    end
  end

  describe "update/3" do
    test "updates an existing entry and moves it to the front" do
      ts =
        %Otel.Trace.TraceState{}
        |> Otel.Trace.TraceState.add("c", "3")
        |> Otel.Trace.TraceState.add("b", "2")
        |> Otel.Trace.TraceState.add("a", "1")
        |> Otel.Trace.TraceState.update("b", "updated")

      assert Otel.Trace.TraceState.encode(ts) == "b=updated,a=1,c=3"
    end

    test "missing key falls through to add semantics, respecting the 32-cap" do
      base =
        Enum.reduce(1..32, %Otel.Trace.TraceState{}, fn i, acc ->
          Otel.Trace.TraceState.add(acc, "key#{i}", "val#{i}")
        end)

      ts = Otel.Trace.TraceState.update(base, "missing", "v")

      assert Otel.Trace.TraceState.get(ts, "missing") == "v"
      # Add semantics drop the right-most (oldest) — only one drop.
      assert Otel.Trace.TraceState.get(ts, "key1") == ""
      assert Otel.Trace.TraceState.get(ts, "key2") == "val2"
    end
  end

  describe "delete/2" do
    test "removes the key; no-op for missing key" do
      ts =
        %Otel.Trace.TraceState{}
        |> Otel.Trace.TraceState.add("b", "2")
        |> Otel.Trace.TraceState.add("a", "1")

      assert Otel.Trace.TraceState.delete(ts, "a")
             |> Otel.Trace.TraceState.encode() == "b=2"

      assert Otel.Trace.TraceState.delete(ts, "missing")
             |> Otel.Trace.TraceState.encode() == "a=1,b=2"
    end
  end

  describe "encode/1 + decode/1 (W3C wire format)" do
    test "round-trips canonical entries" do
      header = "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7"

      assert header
             |> Otel.Trace.TraceState.decode()
             |> Otel.Trace.TraceState.encode() == header
    end

    test "decode tolerates whitespace, empty list-members, and dedupes (last wins)" do
      ts = Otel.Trace.TraceState.decode(" a=1 , , b=2 , a=last ")

      # Last occurrence wins on dedup.
      assert Otel.Trace.TraceState.get(ts, "a") == "last"
      assert Otel.Trace.TraceState.get(ts, "b") == "2"
    end

    test "decode \"\" yields empty TraceState" do
      assert Otel.Trace.TraceState.empty?(Otel.Trace.TraceState.decode(""))
    end
  end

  describe "decode parsing — validation deferred to mutation" do
    # Spec stance: parsing is permissive; validation runs at add/update.
    # Keeps decode lossless so debug tooling can inspect everything.
    test "preserves entries with otherwise-invalid keys" do
      ts = Otel.Trace.TraceState.decode("BAD=v,good=ok")

      assert Otel.Trace.TraceState.get(ts, "BAD") == "v"
      assert Otel.Trace.TraceState.get(ts, "good") == "ok"
    end
  end

  describe "valid_key?/1 — W3C §3.3.1.3.1" do
    test "true for the documented allowed shapes" do
      assert Otel.Trace.TraceState.valid_key?("vendor")
      assert Otel.Trace.TraceState.valid_key?("my-key_1*2/3@system")
      # Level 2: digit-leading and multi-tenant.
      assert Otel.Trace.TraceState.valid_key?("1vendor")
      assert Otel.Trace.TraceState.valid_key?("tenant@system")
      assert Otel.Trace.TraceState.valid_key?("a@b@c")
    end

    test "false for empty, uppercase, disallowed symbols, over-length, non-binary" do
      refute Otel.Trace.TraceState.valid_key?("")
      refute Otel.Trace.TraceState.valid_key?("Vendor")
      refute Otel.Trace.TraceState.valid_key?("vendor!")
      refute Otel.Trace.TraceState.valid_key?("ven dor")
      refute Otel.Trace.TraceState.valid_key?("a" <> String.duplicate("x", 256))
      refute Otel.Trace.TraceState.valid_key?(nil)
      refute Otel.Trace.TraceState.valid_key?(:atom)
      refute Otel.Trace.TraceState.valid_key?(123)
    end
  end

  describe "valid_value?/1 — W3C §3.3.1.3.2" do
    test "true across printable ASCII, internal spaces, full symbol range, 256-char max" do
      assert Otel.Trace.TraceState.valid_value?("hello")
      assert Otel.Trace.TraceState.valid_value?("a b c")
      assert Otel.Trace.TraceState.valid_value?("!\"#$%&'()*+-./:;<>?@[\\]^_`{|}~")
      assert Otel.Trace.TraceState.valid_value?(String.duplicate("x", 256))
    end

    test "false for empty, comma, equals, trailing space, over-length, non-ASCII, control, non-binary" do
      refute Otel.Trace.TraceState.valid_value?("")
      refute Otel.Trace.TraceState.valid_value?("a,b")
      refute Otel.Trace.TraceState.valid_value?("a=b")
      refute Otel.Trace.TraceState.valid_value?("trailing ")
      refute Otel.Trace.TraceState.valid_value?(String.duplicate("x", 257))
      refute Otel.Trace.TraceState.valid_value?("한글")
      refute Otel.Trace.TraceState.valid_value?("café")
      refute Otel.Trace.TraceState.valid_value?("emoji🎉")
      refute Otel.Trace.TraceState.valid_value?("line\nbreak")
      refute Otel.Trace.TraceState.valid_value?("tab\there")
      refute Otel.Trace.TraceState.valid_value?("null\0byte")
      refute Otel.Trace.TraceState.valid_value?(nil)
    end
  end

  # add/update use valid_key?/valid_value? as gates — invalid input
  # is silently dropped (state unchanged) per the moduledoc.
  test "add/update silently drop entries that fail validation" do
    base = Otel.Trace.TraceState.add(%Otel.Trace.TraceState{}, "a", "1")

    assert Otel.Trace.TraceState.add(base, "BAD", "v") == base
    assert Otel.Trace.TraceState.add(base, "good", "a,b") == base
    assert Otel.Trace.TraceState.update(base, "BAD", "v") == base
    assert Otel.Trace.TraceState.update(base, "a", "a,b") == base
  end

  test "all mutation operations return new structs (immutability)" do
    ts1 = Otel.Trace.TraceState.add(%Otel.Trace.TraceState{}, "a", "1")
    ts2 = Otel.Trace.TraceState.add(ts1, "b", "2")
    ts3 = Otel.Trace.TraceState.delete(ts2, "a")

    assert Otel.Trace.TraceState.encode(ts1) == "a=1"
    assert Otel.Trace.TraceState.encode(ts2) == "b=2,a=1"
    assert Otel.Trace.TraceState.encode(ts3) == "b=2"
  end
end
