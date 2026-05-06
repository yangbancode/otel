defmodule Otel.Propagator.TextMapTest do
  use ExUnit.Case, async: true

  describe "default_getter/2 (RFC 9110 §5.3 multi-header join)" do
    test "case-insensitive lookup, nil for missing key" do
      assert Otel.Propagator.TextMap.default_getter([{"TraceParent", "v"}], "traceparent") ==
               "v"

      assert Otel.Propagator.TextMap.default_getter([{"other", "v"}], "traceparent") == nil
    end

    test "joins repeated headers with ',' preserving casing-insensitive matches and order" do
      carrier = [
        {"baggage", "first"},
        {"other", "ignored"},
        {"BAGGAGE", "second"},
        {"Baggage", "third"}
      ]

      assert Otel.Propagator.TextMap.default_getter(carrier, "baggage") ==
               "first,second,third"
    end
  end

  describe "default_setter/3" do
    test "appends a new key, replaces an existing one case-insensitively" do
      assert Otel.Propagator.TextMap.default_setter("new", "val", [{"existing", "v"}]) ==
               [{"existing", "v"}, {"new", "val"}]

      assert Otel.Propagator.TextMap.default_setter("traceparent", "new", [
               {"TraceParent", "old"}
             ]) == [{"traceparent", "new"}]
    end
  end

  # Hardcoded propagator list — TraceContext + Baggage. The
  # facade iterates both on every inject/extract; these tests
  # exercise the composite behaviour through the facade.
  describe "inject/3 + extract/3 — hardcoded TraceContext + Baggage" do
    test "round-trips both traceparent and baggage in one call" do
      span_ctx =
        Otel.Trace.SpanContext.new(%{trace_id: 123, span_id: 456, trace_flags: 1})

      ctx =
        Otel.Ctx.new()
        |> Otel.Trace.set_current_span(span_ctx)
        |> Otel.Baggage.set_current(%{"user_id" => {"42", ""}})

      injected = Otel.Propagator.TextMap.inject(ctx, [])

      assert Enum.any?(injected, fn {k, _v} -> k == "traceparent" end)
      assert Enum.any?(injected, fn {k, _v} -> k == "baggage" end)

      extracted = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), injected)

      assert Otel.Trace.SpanContext.valid?(Otel.Trace.current_span(extracted))
      assert Otel.Baggage.get_value(Otel.Baggage.current(extracted), "user_id") == "42"
    end

    test "empty ctx → empty carrier on inject; empty carrier → empty ctx on extract" do
      ctx = Otel.Ctx.new()

      assert Otel.Propagator.TextMap.inject(ctx, []) == []
      assert Otel.Propagator.TextMap.extract(ctx, []) == ctx
    end
  end
end
