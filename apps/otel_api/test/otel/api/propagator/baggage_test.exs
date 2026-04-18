defmodule Otel.API.Propagator.BaggageTest do
  use ExUnit.Case, async: true

  @setter &Otel.API.Propagator.TextMap.default_setter/3
  @getter &Otel.API.Propagator.TextMap.default_getter/2

  describe "fields/0" do
    test "returns baggage header" do
      assert Otel.API.Propagator.Baggage.fields() == ["baggage"]
    end
  end

  describe "inject/3" do
    test "injects baggage header" do
      baggage = Otel.API.Baggage.set_value(%{}, "userId", "abc123")
      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), baggage)

      carrier = Otel.API.Propagator.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      assert header == "userId=abc123"
    end

    test "injects multiple entries" do
      baggage =
        %{}
        |> Otel.API.Baggage.set_value("a", "1")
        |> Otel.API.Baggage.set_value("b", "2")

      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), baggage)
      carrier = Otel.API.Propagator.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      assert String.contains?(header, "a=1")
      assert String.contains?(header, "b=2")
      assert String.contains?(header, ",")
    end

    test "injects metadata" do
      baggage = Otel.API.Baggage.set_value(%{}, "key", "value", "prop1=val1")
      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), baggage)

      carrier = Otel.API.Propagator.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      assert header == "key=value;prop1=val1"
    end

    test "percent-encodes special characters" do
      baggage = Otel.API.Baggage.set_value(%{}, "key", "hello world")
      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), baggage)

      carrier = Otel.API.Propagator.Baggage.inject(ctx, [], @setter)

      header = Otel.API.Propagator.TextMap.default_getter(carrier, "baggage")
      assert header == "key=hello+world"
    end

    test "does not inject for empty baggage" do
      ctx = Otel.API.Ctx.new()
      carrier = Otel.API.Propagator.Baggage.inject(ctx, [], @setter)
      assert carrier == []
    end
  end

  describe "extract/3" do
    test "extracts simple baggage" do
      carrier = [{"baggage", "userId=abc123"}]
      ctx = Otel.API.Propagator.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.get_baggage(ctx)
      assert Otel.API.Baggage.get_value(baggage, "userId") == "abc123"
    end

    test "extracts multiple entries" do
      carrier = [{"baggage", "a=1,b=2"}]
      ctx = Otel.API.Propagator.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.get_baggage(ctx)
      assert Otel.API.Baggage.get_value(baggage, "a") == "1"
      assert Otel.API.Baggage.get_value(baggage, "b") == "2"
    end

    test "extracts metadata" do
      carrier = [{"baggage", "key=value;prop1=val1"}]
      ctx = Otel.API.Propagator.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.get_baggage(ctx)
      {value, metadata} = Map.get(baggage, "key")
      assert value == "value"
      assert metadata == "prop1=val1"
    end

    test "percent-decodes values" do
      carrier = [{"baggage", "key=hello+world"}]
      ctx = Otel.API.Propagator.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.get_baggage(ctx)
      assert Otel.API.Baggage.get_value(baggage, "key") == "hello world"
    end

    test "returns original context for missing header" do
      ctx = Otel.API.Ctx.new()
      result = Otel.API.Propagator.Baggage.extract(ctx, [], @getter)
      assert result == ctx
    end

    test "returns original context for missing `=`" do
      # api-propagators.md L102 — Extract MUST NOT throw on parse failure.
      carrier = [{"baggage", "noequals"}]
      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.Baggage.extract(ctx, carrier, @getter)
    end

    test "returns original context for garbage header" do
      carrier = [{"baggage", "!!@@##"}]
      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.Baggage.extract(ctx, carrier, @getter)
    end

    test "merges with existing baggage in context" do
      existing = Otel.API.Baggage.set_value(%{}, "existing", "value")
      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), existing)

      carrier = [{"baggage", "new=entry"}]
      new_ctx = Otel.API.Propagator.Baggage.extract(ctx, carrier, @getter)

      baggage = Otel.API.Baggage.get_baggage(new_ctx)
      assert Otel.API.Baggage.get_value(baggage, "existing") == "value"
      assert Otel.API.Baggage.get_value(baggage, "new") == "entry"
    end

    test "remote entry overwrites existing with same name" do
      existing = Otel.API.Baggage.set_value(%{}, "key", "local")
      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), existing)

      carrier = [{"baggage", "key=remote"}]
      new_ctx = Otel.API.Propagator.Baggage.extract(ctx, carrier, @getter)

      baggage = Otel.API.Baggage.get_baggage(new_ctx)
      assert Otel.API.Baggage.get_value(baggage, "key") == "remote"
    end

    test "handles whitespace" do
      carrier = [{"baggage", " a = 1 , b = 2 "}]
      ctx = Otel.API.Propagator.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)

      baggage = Otel.API.Baggage.get_baggage(ctx)
      assert Otel.API.Baggage.get_value(baggage, "a") == "1"
      assert Otel.API.Baggage.get_value(baggage, "b") == "2"
    end

    test "roundtrip inject then extract preserves baggage" do
      original =
        %{}
        |> Otel.API.Baggage.set_value("userId", "abc123")
        |> Otel.API.Baggage.set_value("serverNode", "node-42", "region=us-east")

      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), original)
      carrier = Otel.API.Propagator.Baggage.inject(ctx, [], @setter)

      new_ctx = Otel.API.Propagator.Baggage.extract(Otel.API.Ctx.new(), carrier, @getter)
      extracted = Otel.API.Baggage.get_baggage(new_ctx)

      assert Otel.API.Baggage.get_value(extracted, "userId") == "abc123"
      assert Otel.API.Baggage.get_value(extracted, "serverNode") == "node-42"
      {_val, metadata} = Map.get(extracted, "serverNode")
      assert metadata == "region=us-east"
    end
  end
end
