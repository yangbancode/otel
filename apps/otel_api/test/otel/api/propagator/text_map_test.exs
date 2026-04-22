defmodule Otel.API.Propagator.TextMapTest do
  use ExUnit.Case, async: false

  setup do
    :persistent_term.erase({Otel.API.Propagator.TextMap, :global})
    :ok
  end

  describe "get/set_propagator" do
    test "returns Noop by default (spec L322-L325 MUST)" do
      assert Otel.API.Propagator.TextMap.get_propagator() == Otel.API.Propagator.TextMap.Noop
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

    test "erasing the registration reverts to Noop" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)
      :persistent_term.erase({Otel.API.Propagator.TextMap, :global})

      assert Otel.API.Propagator.TextMap.get_propagator() == Otel.API.Propagator.TextMap.Noop
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

    test "joins multiple matches with ', ' (RFC 9110 §5.3)" do
      carrier = [{"baggage", "a=1"}, {"baggage", "b=2"}]
      assert Otel.API.Propagator.TextMap.default_getter(carrier, "baggage") == "a=1, b=2"
    end

    test "joins multiple matches across different casings" do
      carrier = [{"Baggage", "a=1"}, {"BAGGAGE", "b=2"}, {"baggage", "c=3"}]
      assert Otel.API.Propagator.TextMap.default_getter(carrier, "baggage") == "a=1, b=2, c=3"
    end

    test "preserves order of matching headers" do
      carrier = [
        {"baggage", "first"},
        {"other", "ignored"},
        {"baggage", "second"},
        {"baggage", "third"}
      ]

      assert Otel.API.Propagator.TextMap.default_getter(carrier, "baggage") ==
               "first, second, third"
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

  describe "inject/3 convenience" do
    test "returns carrier unchanged when no global propagator" do
      carrier = [{"existing", "value"}]
      ctx = Otel.API.Ctx.new()
      assert Otel.API.Propagator.TextMap.inject(ctx, carrier) == carrier
    end

    test "dispatches to global propagator" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)

      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.inject(ctx, [])
      assert Enum.any?(carrier, fn {k, _v} -> k == "traceparent" end)
    end
  end

  describe "extract/3 convenience" do
    test "returns context unchanged when no global propagator" do
      ctx = Otel.API.Ctx.new()
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      assert Otel.API.Propagator.TextMap.extract(ctx, carrier) == ctx
    end

    test "dispatches to global propagator" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)

      ctx = Otel.API.Ctx.new()
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      new_ctx = Otel.API.Propagator.TextMap.extract(ctx, carrier)

      span_ctx = Otel.API.Trace.current_span(new_ctx)
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
    end
  end
end
