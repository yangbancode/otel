defmodule Otel.API.Propagator.TextMapTest do
  use ExUnit.Case, async: false

  setup do
    saved = :persistent_term.get({Otel.API.Propagator.TextMap, :global}, nil)
    :persistent_term.erase({Otel.API.Propagator.TextMap, :global})

    on_exit(fn ->
      if saved,
        do: :persistent_term.put({Otel.API.Propagator.TextMap, :global}, saved),
        else: :persistent_term.erase({Otel.API.Propagator.TextMap, :global})
    end)
  end

  describe "set_propagator/1 + get_propagator/0" do
    # Spec context/api-propagators.md L322-L325 MUST: default Noop.
    test "defaults to Noop, accepts module or {module, opts} tuple" do
      assert Otel.API.Propagator.TextMap.get_propagator() == Otel.API.Propagator.TextMap.Noop

      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)

      assert Otel.API.Propagator.TextMap.get_propagator() ==
               Otel.API.Propagator.TextMap.TraceContext

      composite =
        {Otel.API.Propagator.TextMap.Composite, [Otel.API.Propagator.TextMap.TraceContext]}

      Otel.API.Propagator.TextMap.set_propagator(composite)
      assert Otel.API.Propagator.TextMap.get_propagator() == composite
    end

    test "erasing the registration reverts to Noop" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)
      :persistent_term.erase({Otel.API.Propagator.TextMap, :global})

      assert Otel.API.Propagator.TextMap.get_propagator() == Otel.API.Propagator.TextMap.Noop
    end
  end

  describe "default_getter/2 (RFC 9110 §5.3 multi-header join)" do
    test "case-insensitive lookup, nil for missing key" do
      assert Otel.API.Propagator.TextMap.default_getter([{"TraceParent", "v"}], "traceparent") ==
               "v"

      assert Otel.API.Propagator.TextMap.default_getter([{"other", "v"}], "traceparent") == nil
    end

    test "joins repeated headers with ',' preserving casing-insensitive matches and order" do
      carrier = [
        {"baggage", "first"},
        {"other", "ignored"},
        {"BAGGAGE", "second"},
        {"Baggage", "third"}
      ]

      assert Otel.API.Propagator.TextMap.default_getter(carrier, "baggage") ==
               "first,second,third"
    end
  end

  describe "default_setter/3" do
    test "appends a new key, replaces an existing one case-insensitively" do
      assert Otel.API.Propagator.TextMap.default_setter("new", "val", [{"existing", "v"}]) ==
               [{"existing", "v"}, {"new", "val"}]

      assert Otel.API.Propagator.TextMap.default_setter("traceparent", "new", [
               {"TraceParent", "old"}
             ]) == [{"traceparent", "new"}]
    end
  end

  describe "inject/2 + extract/2 convenience" do
    test "pass through when no propagator is registered (Noop dispatch)" do
      ctx = Otel.API.Ctx.new()
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]

      assert Otel.API.Propagator.TextMap.inject(ctx, carrier) == carrier
      assert Otel.API.Propagator.TextMap.extract(ctx, carrier) == ctx
    end

    test "dispatch to the registered propagator (TraceContext round-trip)" do
      Otel.API.Propagator.TextMap.set_propagator(Otel.API.Propagator.TextMap.TraceContext)

      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx_with_span = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      injected = Otel.API.Propagator.TextMap.inject(ctx_with_span, [])
      assert Enum.any?(injected, fn {k, _v} -> k == "traceparent" end)

      extracted = Otel.API.Propagator.TextMap.extract(Otel.API.Ctx.new(), injected)
      assert Otel.API.Trace.SpanContext.valid?(Otel.API.Trace.current_span(extracted))
    end
  end
end
