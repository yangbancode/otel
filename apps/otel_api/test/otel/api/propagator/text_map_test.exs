defmodule Otel.API.Propagator.TextMapTest do
  use ExUnit.Case, async: false

  setup do
    :persistent_term.erase({Otel.API.Propagator.TextMap, :global})
    :ok
  end

  describe "get/set_propagator" do
    test "returns nil by default" do
      assert Otel.API.Propagator.TextMap.get_propagator() == nil
    end

    test "sets and gets propagator module" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)

      assert Otel.API.Propagator.TextMap.get_propagator() ==
               Otel.API.Propagator.TextMap.TraceContext
    end

    test "sets and gets propagator tuple" do
      propagator =
        {Otel.API.Propagator.TextMap.Composite, [Otel.API.Propagator.TextMap.TraceContext]}

      Otel.API.Propagator.TextMap.set_propagator(propagator)
      assert Otel.API.Propagator.TextMap.get_propagator() == propagator
    end
  end

  describe "default_getter/2" do
    test "returns value for matching key" do
      carrier = [{"traceparent", "00-abc-def-01"}]
      assert Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent") == "00-abc-def-01"
    end

    test "case-insensitive lookup" do
      carrier = [{"TraceParent", "value"}]
      assert Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent") == "value"
    end

    test "returns nil for missing key" do
      carrier = [{"other", "value"}]
      assert Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent") == nil
    end

    test "returns first match" do
      carrier = [{"key", "first"}, {"key", "second"}]
      assert Otel.API.Propagator.TextMap.default_getter(carrier, "key") == "first"
    end
  end

  describe "default_get_all/2" do
    test "returns all values for matching key" do
      carrier = [{"baggage", "a=1"}, {"other", "x"}, {"baggage", "b=2"}]
      assert Otel.API.Propagator.TextMap.default_get_all(carrier, "baggage") == ["a=1", "b=2"]
    end

    test "case-insensitive lookup" do
      carrier = [{"Baggage", "a=1"}, {"BAGGAGE", "b=2"}]
      assert Otel.API.Propagator.TextMap.default_get_all(carrier, "baggage") == ["a=1", "b=2"]
    end

    test "returns empty list for missing key" do
      assert Otel.API.Propagator.TextMap.default_get_all([], "baggage") == []
    end

    test "preserves carrier order" do
      carrier = [{"key", "third"}, {"other", "x"}, {"key", "first"}, {"key", "second"}]

      assert Otel.API.Propagator.TextMap.default_get_all(carrier, "key") == [
               "third",
               "first",
               "second"
             ]
    end
  end

  describe "default_setter/3" do
    test "appends new key" do
      carrier = [{"existing", "value"}]
      result = Otel.API.Propagator.TextMap.default_setter("new", "val", carrier)
      assert result == [{"existing", "value"}, {"new", "val"}]
    end

    test "replaces existing key case-insensitively" do
      carrier = [{"TraceParent", "old"}]
      result = Otel.API.Propagator.TextMap.default_setter("traceparent", "new", carrier)
      assert result == [{"traceparent", "new"}]
    end
  end

  describe "default_keys/1" do
    test "returns all keys" do
      carrier = [{"traceparent", "val"}, {"tracestate", "val2"}]
      assert Otel.API.Propagator.TextMap.default_keys(carrier) == ["traceparent", "tracestate"]
    end

    test "returns empty list for empty carrier" do
      assert Otel.API.Propagator.TextMap.default_keys([]) == []
    end
  end

  describe "inject/3 convenience" do
    test "returns carrier unchanged when no global propagator" do
      carrier = [{"existing", "value"}]
      ctx = %{}
      assert Otel.API.Propagator.TextMap.inject(ctx, carrier) == carrier
    end

    test "dispatches to global propagator" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)

      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(%{}, span_ctx)

      carrier = Otel.API.Propagator.TextMap.inject(ctx, [])
      assert Enum.any?(carrier, fn {k, _v} -> k == "traceparent" end)
    end
  end

  describe "extract/3 convenience" do
    test "returns context unchanged when no global propagator" do
      ctx = %{}
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      assert Otel.API.Propagator.TextMap.extract(ctx, carrier) == ctx
    end

    test "dispatches to global propagator" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)

      ctx = %{}
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      new_ctx = Otel.API.Propagator.TextMap.extract(ctx, carrier)

      span_ctx = Otel.API.Trace.current_span(new_ctx)
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
    end
  end
end
