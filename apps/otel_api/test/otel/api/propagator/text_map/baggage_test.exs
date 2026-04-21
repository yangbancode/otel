defmodule Otel.API.Propagator.TextMap.BaggageTest do
  use ExUnit.Case, async: true

  @setter &Otel.API.Propagator.TextMap.default_setter/3
  @getter &Otel.API.Propagator.TextMap.default_getter/2

  describe "fields/0" do
    test "returns baggage header" do
      assert Otel.API.Propagator.TextMap.Baggage.fields() == ["baggage"]
    end
  end

  describe "inject/3" do
    test "injects baggage header" do
      baggage = Otel.API.Baggage.set_value(%{}, "userId", "abc123")
      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), baggage)

      carrier = Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      assert header == "userId=abc123"
    end

    test "injects multiple entries" do
      baggage =
        %{}
        |> Otel.API.Baggage.set_value("a", "1")
        |> Otel.API.Baggage.set_value("b", "2")

      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), baggage)
      carrier = Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      assert String.contains?(header, "a=1")
      assert String.contains?(header, "b=2")
      assert String.contains?(header, ",")
    end

    test "injects metadata" do
      baggage = Otel.API.Baggage.set_value(%{}, "key", "value", "prop1=val1")
      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), baggage)

      carrier = Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      assert header == "key=value;prop1=val1"
    end

    test "percent-encodes special characters per RFC 3986" do
      baggage = Otel.API.Baggage.set_value(%{}, "key", "hello world")
      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), baggage)

      carrier = Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      # Space → %20 per RFC 3986, not + (which would be form-urlencoding).
      assert header == "key=hello%20world"
    end

    test "does not inject for empty baggage" do
      ctx = Otel.API.Ctx.new()
      carrier = Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)
      assert carrier == []
    end
  end

  describe "extract/3" do
    test "extracts simple baggage" do
      carrier = [{"baggage", "userId=abc123"}]
      ctx = Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.current(ctx)
      assert Otel.API.Baggage.get_value(baggage, "userId") == "abc123"
    end

    test "extracts multiple entries" do
      carrier = [{"baggage", "a=1,b=2"}]
      ctx = Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.current(ctx)
      assert Otel.API.Baggage.get_value(baggage, "a") == "1"
      assert Otel.API.Baggage.get_value(baggage, "b") == "2"
    end

    test "extracts metadata" do
      carrier = [{"baggage", "key=value;prop1=val1"}]
      ctx = Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.current(ctx)
      {value, metadata} = Map.get(baggage, "key")
      assert value == "value"
      assert metadata == "prop1=val1"
    end

    test "percent-decodes %20 to space per RFC 3986" do
      carrier = [{"baggage", "key=hello%20world"}]
      ctx = Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.current(ctx)
      assert Otel.API.Baggage.get_value(baggage, "key") == "hello world"
    end

    test "preserves literal + in value (RFC 3986)" do
      # Per W3C §Definition L32, `+` (0x2B) is inside `baggage-octet`
      # and MUST be treated as a literal plus character — not as
      # an encoded space. This is a key difference from form-urlencoding.
      carrier = [{"baggage", "key=a+b"}]
      ctx = Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.current(ctx)
      assert Otel.API.Baggage.get_value(baggage, "key") == "a+b"
    end

    test "returns original context for missing header" do
      ctx = Otel.API.Ctx.new()
      result = Otel.API.Propagator.TextMap.Baggage.extract(ctx, [], @getter)
      assert result == ctx
    end

    test "returns original context for missing `=`" do
      # api-propagators.md L102 — Extract MUST NOT throw on parse failure.
      carrier = [{"baggage", "noequals"}]
      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.Baggage.extract(ctx, carrier, @getter)
    end

    test "returns original context for garbage header" do
      carrier = [{"baggage", "!!@@##"}]
      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.Baggage.extract(ctx, carrier, @getter)
    end

    test "merges with existing baggage in context" do
      existing = Otel.API.Baggage.set_value(%{}, "existing", "value")
      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), existing)

      carrier = [{"baggage", "new=entry"}]
      new_ctx = Otel.API.Propagator.TextMap.Baggage.extract(ctx, carrier, @getter)

      baggage = Otel.API.Baggage.current(new_ctx)
      assert Otel.API.Baggage.get_value(baggage, "existing") == "value"
      assert Otel.API.Baggage.get_value(baggage, "new") == "entry"
    end

    test "remote entry overwrites existing with same name" do
      existing = Otel.API.Baggage.set_value(%{}, "key", "local")
      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), existing)

      carrier = [{"baggage", "key=remote"}]
      new_ctx = Otel.API.Propagator.TextMap.Baggage.extract(ctx, carrier, @getter)

      baggage = Otel.API.Baggage.current(new_ctx)
      assert Otel.API.Baggage.get_value(baggage, "key") == "remote"
    end

    test "handles whitespace" do
      carrier = [{"baggage", " a = 1 , b = 2 "}]
      ctx = Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.current(ctx)
      assert Otel.API.Baggage.get_value(baggage, "a") == "1"
      assert Otel.API.Baggage.get_value(baggage, "b") == "2"
    end

    test "roundtrip inject then extract preserves baggage" do
      original =
        %{}
        |> Otel.API.Baggage.set_value("userId", "abc123")
        |> Otel.API.Baggage.set_value("serverNode", "node-42", "region=us-east")

      ctx = Otel.API.Baggage.set_current(Otel.API.Ctx.new(), original)
      carrier = Otel.API.Propagator.TextMap.Baggage.inject(ctx, [], @setter)

      new_ctx = Otel.API.Propagator.TextMap.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)
      extracted = Otel.API.Baggage.current(new_ctx)

      assert Otel.API.Baggage.get_value(extracted, "userId") == "abc123"
      assert Otel.API.Baggage.get_value(extracted, "serverNode") == "node-42"
      {_val, metadata} = Map.get(extracted, "serverNode")
      assert metadata == "region=us-east"
    end
  end

  describe "encode_baggage/1" do
    test "empty map returns empty string" do
      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(%{}) == ""
    end

    test "single entry without metadata" do
      baggage = %{"key" => {"value", ""}}
      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(baggage) == "key=value"
    end

    test "single entry with metadata appended verbatim" do
      baggage = %{"key" => {"value", "prop1=val1"}}

      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(baggage) ==
               "key=value;prop1=val1"
    end

    test "multiple entries joined with comma" do
      baggage = %{"a" => {"1", ""}, "b" => {"2", ""}}
      header = Otel.API.Propagator.TextMap.Baggage.encode_baggage(baggage)
      assert String.contains?(header, "a=1")
      assert String.contains?(header, "b=2")
      assert String.contains?(header, ",")
    end

    test "percent-encodes space as %20 per RFC 3986" do
      baggage = %{"key" => {"hello world", ""}}

      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(baggage) ==
               "key=hello%20world"
    end

    test "percent-encodes literal + as %2B (not treated as space)" do
      baggage = %{"key" => {"a+b", ""}}
      assert Otel.API.Propagator.TextMap.Baggage.encode_baggage(baggage) == "key=a%2Bb"
    end
  end

  describe "decode_baggage/1" do
    test "empty string returns empty map" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("") == %{}
    end

    test "single entry" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("key=value") ==
               %{"key" => {"value", ""}}
    end

    test "single entry with metadata kept as opaque string" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("key=value;prop1=val1") ==
               %{"key" => {"value", "prop1=val1"}}
    end

    test "multiple entries" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("a=1,b=2") ==
               %{"a" => {"1", ""}, "b" => {"2", ""}}
    end

    test "percent-decodes %20 to space per RFC 3986" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("key=hello%20world") ==
               %{"key" => {"hello world", ""}}
    end

    test "preserves literal + (RFC 3986, not form-urlencoding)" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage("key=a+b") ==
               %{"key" => {"a+b", ""}}
    end

    test "trims whitespace around entries" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_baggage(" a = 1 , b = 2 ") ==
               %{"a" => {"1", ""}, "b" => {"2", ""}}
    end

    test "raises on list-member without =" do
      assert_raise MatchError, fn ->
        Otel.API.Propagator.TextMap.Baggage.decode_baggage("noequals")
      end
    end
  end

  describe "decode_entry/1" do
    test "parses key=value" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_entry("key=value") ==
               {"key", "value", ""}
    end

    test "parses key=value;metadata" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_entry("key=value;prop1=val1") ==
               {"key", "value", "prop1=val1"}
    end

    test "trims whitespace around key and value" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_entry(" key = value ") ==
               {"key", "value", ""}
    end

    test "percent-decodes key and value (RFC 3986)" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_entry("key%20a=value%20b") ==
               {"key a", "value b", ""}
    end

    test "value may contain additional = (W3C L73-L74)" do
      # Parsers MUST NOT assume the equal sign is only used to separate key and value.
      assert Otel.API.Propagator.TextMap.Baggage.decode_entry("key=a=b") ==
               {"key", "a=b", ""}
    end

    test "metadata with multiple properties kept as opaque string" do
      assert Otel.API.Propagator.TextMap.Baggage.decode_entry("key=v;k1=v1;k2=v2") ==
               {"key", "v", "k1=v1;k2=v2"}
    end

    test "raises on pair without =" do
      assert_raise MatchError, fn ->
        Otel.API.Propagator.TextMap.Baggage.decode_entry("noequals")
      end
    end
  end
end
