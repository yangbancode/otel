defmodule Otel.BaggageTest do
  use ExUnit.Case, async: false

  describe "get_value/2 + get_all/1" do
    test "get_value returns the value or nil; get_all returns the whole map" do
      baggage = %{"a" => {"1", ""}, "b" => {"2", "meta"}}

      assert Otel.Baggage.get_value(baggage, "a") == "1"
      assert Otel.Baggage.get_value(baggage, "missing") == nil
      assert Otel.Baggage.get_all(baggage) == baggage
      assert Otel.Baggage.get_all(%{}) == %{}
    end
  end

  describe "set_value/4" do
    test "adds, overwrites, and carries metadata in one shape" do
      empty = %{}

      assert Otel.Baggage.set_value(empty, "k", "v") == %{"k" => {"v", ""}}

      assert Otel.Baggage.set_value(empty, "k", "v", "meta=data") ==
               %{"k" => {"v", "meta=data"}}

      assert Otel.Baggage.set_value(%{"k" => {"old", ""}}, "k", "new") ==
               %{"k" => {"new", ""}}
    end

    # Spec baggage/api.md L62-L67: names and values are case-sensitive.
    test "names and values are case-sensitive (verbatim UTF-8)" do
      baggage =
        %{}
        |> Otel.Baggage.set_value("Key", "Value")
        |> Otel.Baggage.set_value("key", "lower")
        |> Otel.Baggage.set_value("utf8", "B% 💼 café Δ")

      assert Otel.Baggage.get_value(baggage, "Key") == "Value"
      assert Otel.Baggage.get_value(baggage, "key") == "lower"
      assert Otel.Baggage.get_value(baggage, "utf8") == "B% 💼 café Δ"
    end
  end

  describe "remove_value/2" do
    test "removes existing entry; no-op for missing key" do
      assert Otel.Baggage.remove_value(%{"k" => {"v", ""}}, "k") == %{}

      assert Otel.Baggage.remove_value(%{"other" => {"v", ""}}, "k") == %{
               "other" => {"v", ""}
             }
    end
  end

  describe "Context integration" do
    test "current/1 + set_current/2 round-trip on an explicit context" do
      ctx = Otel.Ctx.new()
      baggage = %{"k" => {"v", ""}}

      assert Otel.Baggage.current(ctx) == %{}

      ctx = Otel.Baggage.set_current(ctx, baggage)
      assert Otel.Baggage.current(ctx) == baggage

      ctx = Otel.Baggage.set_current(ctx, %{})
      assert Otel.Baggage.current(ctx) == %{}
    end

    test "current/0 + set_current/1 round-trip on the implicit context" do
      Otel.Baggage.set_current(%{})
      assert Otel.Baggage.current() == %{}

      Otel.Baggage.set_current(%{"k" => {"v", ""}})
      assert Otel.Baggage.current() == %{"k" => {"v", ""}}

      Otel.Baggage.set_current(%{})
      assert Otel.Baggage.current() == %{}
    end
  end
end
