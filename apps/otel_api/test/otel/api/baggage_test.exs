defmodule Otel.API.BaggageTest do
  use ExUnit.Case, async: true

  describe "get_value/2" do
    test "returns value for existing name" do
      baggage = %{"key" => {"value", ""}}
      assert Otel.API.Baggage.get_value(baggage, "key") == "value"
    end

    test "returns nil for missing name" do
      assert Otel.API.Baggage.get_value(%{}, "key") == nil
    end
  end

  describe "get_all/1" do
    test "returns all entries" do
      baggage = %{"a" => {"1", ""}, "b" => {"2", "meta"}}
      assert Otel.API.Baggage.get_all(baggage) == baggage
    end

    test "returns empty map for empty baggage" do
      assert Otel.API.Baggage.get_all(%{}) == %{}
    end
  end

  describe "set_value/4" do
    test "adds new entry" do
      baggage = Otel.API.Baggage.set_value(%{}, "key", "value")
      assert baggage == %{"key" => {"value", ""}}
    end

    test "adds entry with metadata" do
      baggage = Otel.API.Baggage.set_value(%{}, "key", "value", "meta=data")
      assert baggage == %{"key" => {"value", "meta=data"}}
    end

    test "overwrites existing entry" do
      baggage = %{"key" => {"old", ""}}
      updated = Otel.API.Baggage.set_value(baggage, "key", "new")
      assert updated == %{"key" => {"new", ""}}
    end

    test "names are case-sensitive" do
      baggage =
        %{}
        |> Otel.API.Baggage.set_value("Key", "upper")
        |> Otel.API.Baggage.set_value("key", "lower")

      assert Otel.API.Baggage.get_value(baggage, "Key") == "upper"
      assert Otel.API.Baggage.get_value(baggage, "key") == "lower"
    end

    test "values are case-sensitive" do
      baggage = Otel.API.Baggage.set_value(%{}, "key", "Value")
      assert Otel.API.Baggage.get_value(baggage, "key") == "Value"
      refute Otel.API.Baggage.get_value(baggage, "key") == "value"
    end

    test "accepts UTF-8 value and roundtrips verbatim" do
      utf8_value = "B% 💼 café Δ"
      baggage = Otel.API.Baggage.set_value(%{}, "key", utf8_value)
      assert Otel.API.Baggage.get_value(baggage, "key") == utf8_value
    end
  end

  describe "remove_value/2" do
    test "removes existing entry" do
      baggage = %{"key" => {"value", ""}}
      assert Otel.API.Baggage.remove_value(baggage, "key") == %{}
    end

    test "no-op for missing name" do
      baggage = %{"other" => {"value", ""}}
      assert Otel.API.Baggage.remove_value(baggage, "key") == baggage
    end
  end

  describe "context interaction (explicit)" do
    test "get_baggage returns empty map by default" do
      ctx = Otel.API.Ctx.new()
      assert Otel.API.Baggage.get_baggage(ctx) == %{}
    end

    test "set_baggage and get_baggage roundtrip" do
      baggage = %{"key" => {"value", ""}}
      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), baggage)
      assert Otel.API.Baggage.get_baggage(ctx) == baggage
    end

    test "clear removes all entries from context" do
      baggage = %{"a" => {"1", ""}, "b" => {"2", ""}}
      ctx = Otel.API.Baggage.set_baggage(Otel.API.Ctx.new(), baggage)
      cleared = Otel.API.Baggage.clear(ctx)
      assert Otel.API.Baggage.get_baggage(cleared) == %{}
    end
  end

  describe "context interaction (implicit)" do
    test "get_baggage returns empty map by default" do
      assert Otel.API.Baggage.get_baggage() == %{}
    end

    test "set_baggage and get_baggage roundtrip" do
      baggage = %{"key" => {"value", ""}}
      Otel.API.Baggage.set_baggage(baggage)
      assert Otel.API.Baggage.get_baggage() == baggage
    end

    test "clear removes all entries" do
      Otel.API.Baggage.set_baggage(%{"key" => {"value", ""}})
      Otel.API.Baggage.clear()
      assert Otel.API.Baggage.get_baggage() == %{}
    end
  end
end
