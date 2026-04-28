defmodule Otel.API.Propagator.TextMap.BaggageTest do
  use ExUnit.Case, async: true

  @setter &Otel.API.Propagator.TextMap.default_setter/3
  @getter &Otel.API.Propagator.TextMap.default_getter/2

  test "fields/0 returns [\"baggage\"]" do
    assert Otel.API.Propagator.TextMap.Baggage.fields() == ["baggage"]
  end

  describe "inject/3" do
    test "writes the baggage header for non-empty Baggage" do
      baggage =
        %{}
        |> Otel.API.Baggage.set_value("a", "1")
        |> Otel.API.Baggage.set_value("b", "2")

      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), baggage)

      header =
        Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)
        |> Otel.API.Propagator.TextMap.default_getter("baggage")

      assert String.contains?(header, "a=1")
      assert String.contains?(header, "b=2")
      assert String.contains?(header, ",")
    end

    test "appends metadata; percent-encodes space (RFC 3986, not form-urlencoding)" do
      baggage =
        %{}
        |> Otel.API.Baggage.set_value("key", "hello world")
        |> Otel.API.Baggage.set_value("svc", "node-42", "region=us-east")

      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), baggage)

      header =
        Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)
        |> Otel.API.Propagator.TextMap.default_getter("baggage")

      assert String.contains?(header, "key=hello%20world")
      assert String.contains?(header, "svc=node-42;region=us-east")
    end

    test "no-op when Baggage is empty" do
      assert Otel.API.Propagator.TextMap.Baggage.inject(Otel.API.Ctx.new(), [], @setter) == []
    end
  end

  describe "extract/3" do
    test "parses simple, multi-entry, and metadata-bearing headers" do
      carrier = [{"baggage", "userId=abc123,svc=node-42;region=us-east"}]

      baggage =
        Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)
        |> Otel.API.Baggage.current()

      assert Otel.API.Baggage.get_value(baggage, "userId") == "abc123"
      assert {"node-42", "region=us-east"} = Map.fetch!(baggage, "svc")
    end

    # W3C Baggage L6 — multiple `baggage` headers MUST be supported;
    # the default getter joins them with ",", so all entries survive.
    test "merges entries across multiple baggage headers" do
      carrier = [
        {"baggage", "a=1"},
        {"baggage", "b=2"},
        {"baggage", "c=3"}
      ]

      baggage =
        Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)
        |> Otel.API.Baggage.current()

      assert Otel.API.Baggage.get_value(baggage, "a") == "1"
      assert Otel.API.Baggage.get_value(baggage, "b") == "2"
      assert Otel.API.Baggage.get_value(baggage, "c") == "3"
    end

    test "decodes %20 to space; preserves literal + (RFC 3986, not form-urlencoding)" do
      carrier = [{"baggage", "spaced=hello%20world,plus=a+b"}]

      baggage =
        Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)
        |> Otel.API.Baggage.current()

      assert Otel.API.Baggage.get_value(baggage, "spaced") == "hello world"
      assert Otel.API.Baggage.get_value(baggage, "plus") == "a+b"
    end

    test "trims whitespace around list-members and key/value separators" do
      carrier = [{"baggage", " a = 1 , b = 2 "}]

      baggage =
        Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)
        |> Otel.API.Baggage.current()

      assert Otel.API.Baggage.get_value(baggage, "a") == "1"
      assert Otel.API.Baggage.get_value(baggage, "b") == "2"
    end

    test "merges with existing Baggage; remote entries overwrite same-key local entries" do
      existing =
        %{}
        |> Otel.API.Baggage.set_value("local_only", "kept")
        |> Otel.API.Baggage.set_value("conflict", "local")

      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), existing)
      carrier = [{"baggage", "remote_only=new,conflict=remote"}]

      baggage =
        Otel.API.Propagator.TextMap.Baggage.extract(ctx, carrier, @getter)
        |> Otel.API.Baggage.current()

      assert Otel.API.Baggage.get_value(baggage, "local_only") == "kept"
      assert Otel.API.Baggage.get_value(baggage, "remote_only") == "new"
      assert Otel.API.Baggage.get_value(baggage, "conflict") == "remote"
    end

    # Spec api-propagators.md L102 — extract MUST NOT throw on parse
    # failure; it returns the original Context unchanged.
    test "leaves Context unchanged on missing header or malformed input" do
      ctx = Otel.API.Ctx.new()

      assert Otel.API.Propagator.TextMap.Baggage.extract(ctx, [], @getter) == ctx

      assert Otel.API.Propagator.TextMap.Baggage.extract(
               ctx,
               [{"baggage", "noequals"}],
               @getter
             ) == ctx

      assert Otel.API.Propagator.TextMap.Baggage.extract(
               ctx,
               [{"baggage", "!!@@##"}],
               @getter
             ) == ctx
    end
  end

  test "inject + extract round-trip preserves keys, values, and metadata" do
    original =
      %{}
      |> Otel.API.Baggage.set_value("userId", "abc123")
      |> Otel.API.Baggage.set_value("svc", "node-42", "region=us-east")

    carrier =
      Otel.API.Baggage.set_current(Otel.API.Ctx.new(), original)
      |> Otel.API.Propagator.TextMap.Baggage.inject([], @setter)

    extracted =
      Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)
      |> Otel.API.Baggage.current()

    assert Otel.API.Baggage.get_value(extracted, "userId") == "abc123"
    assert {"node-42", "region=us-east"} = Map.fetch!(extracted, "svc")
  end

  describe "encode_baggage/1" do
    test "empty map → empty string" do
      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(%{}) == ""
    end

    test "single entry, with and without metadata" do
      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(%{"key" => {"value", ""}}) ==
               "key=value"

      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(%{
               "key" => {"value", "prop1=val1"}
             }) == "key=value;prop1=val1"
    end

    test "percent-encodes space as %20 and literal + as %2B (RFC 3986)" do
      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(%{"k" => {"hello world", ""}}) ==
               "k=hello%20world"

      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(%{"k" => {"a+b", ""}}) ==
               "k=a%2Bb"
    end

    test "joins multiple entries with comma" do
      header =
        Otel.API.Propagator.TextMap.Baggage.encode_baggage(%{"a" => {"1", ""}, "b" => {"2", ""}})

      assert String.contains?(header, "a=1")
      assert String.contains?(header, "b=2")
      assert String.contains?(header, ",")
    end
  end

  describe "decode_baggage/1" do
    test "empty / single / multiple / metadata-bearing inputs" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("") == %{}

      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("key=value") ==
               %{"key" => {"value", ""}}

      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("key=value;prop1=val1") ==
               %{"key" => {"value", "prop1=val1"}}

      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("a=1,b=2") ==
               %{"a" => {"1", ""}, "b" => {"2", ""}}
    end

    test "percent-decodes %20 to space; preserves literal +; trims whitespace" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("k=hello%20world") ==
               %{"k" => {"hello world", ""}}

      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("k=a+b") ==
               %{"k" => {"a+b", ""}}

      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage(" a = 1 , b = 2 ") ==
               %{"a" => {"1", ""}, "b" => {"2", ""}}
    end

    # decode_baggage is the strict (raising) variant; extract/3 uses
    # it under a try/rescue for the propagator's L102 MUST NOT throw.
    test "raises on a list-member that lacks `=`" do
      assert_raise MatchError, fn ->
        Otel.API.Propagator.TextMap.Baggage.decode_baggage("noequals")
      end
    end
  end
end
