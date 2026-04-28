defmodule Otel.API.Propagator.TextMap.CompositeTest do
  use ExUnit.Case, async: false

  defmodule FakePropagator do
    @moduledoc false
    @behaviour Otel.API.Propagator.TextMap

    @impl true
    def inject(_ctx, carrier, setter), do: setter.("x-fake", "injected", carrier)

    @impl true
    def extract(ctx, carrier, getter) do
      case getter.(carrier, "x-fake") do
        nil -> ctx
        value -> Otel.API.Ctx.set_value(ctx, :fake_value, value)
      end
    end

    @impl true
    def fields, do: ["x-fake"]
  end

  @trace_context Otel.API.Propagator.TextMap.TraceContext
  @fake FakePropagator
  @valid_traceparent "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

  test "new/1 wraps the propagator list as a {Composite, list} tuple" do
    assert Otel.API.Propagator.TextMap.Composite.new([@trace_context, @fake]) ==
             {Otel.API.Propagator.TextMap.Composite, [@trace_context, @fake]}
  end

  describe "inject/4 + extract/4 — dispatches through every propagator" do
    test "inject runs each propagator in order; extract threads context through them" do
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier =
        Otel.API.Propagator.TextMap.Composite.inject(
          [@trace_context, @fake],
          ctx,
          [],
          &Otel.API.Propagator.TextMap.default_setter/3
        )

      keys = Enum.map(carrier, fn {k, _v} -> k end)
      assert "traceparent" in keys
      assert "x-fake" in keys

      extracted =
        Otel.API.Propagator.TextMap.Composite.extract(
          [@trace_context, @fake],
          Otel.API.Ctx.new(),
          [{"traceparent", @valid_traceparent}, {"x-fake", "hello"}],
          &Otel.API.Propagator.TextMap.default_getter/2
        )

      assert Otel.API.Trace.SpanContext.valid?(Otel.API.Trace.current_span(extracted))
      assert Otel.API.Ctx.get_value(extracted, :fake_value) == "hello"
    end
  end

  describe "global registration as {Composite, list} dispatches via the facade" do
    setup do
      saved = :persistent_term.get({Otel.API.Propagator.TextMap, :global}, nil)

      Otel.API.Propagator.TextMap.set_propagator(
        Otel.API.Propagator.TextMap.Composite.new([@trace_context, @fake])
      )

      on_exit(fn ->
        if saved,
          do: :persistent_term.put({Otel.API.Propagator.TextMap, :global}, saved),
          else: :persistent_term.erase({Otel.API.Propagator.TextMap, :global})
      end)
    end

    test "inject + extract round-trip through the facade reach every propagator" do
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.inject(ctx, [])
      keys = Enum.map(carrier, fn {k, _v} -> k end)
      assert "traceparent" in keys
      assert "x-fake" in keys

      extracted =
        Otel.API.Propagator.TextMap.extract(Otel.API.Ctx.new(), [
          {"traceparent", @valid_traceparent},
          {"x-fake", "hello"}
        ])

      assert Otel.API.Trace.SpanContext.valid?(Otel.API.Trace.current_span(extracted))
      assert Otel.API.Ctx.get_value(extracted, :fake_value) == "hello"
    end
  end

  describe "fields/1" do
    test "returns the union of all propagators' fields, deduplicated" do
      fields = Otel.API.Propagator.TextMap.Composite.fields([@trace_context, @fake])
      assert "traceparent" in fields
      assert "tracestate" in fields
      assert "x-fake" in fields

      # Repeated propagators do not yield duplicate field names.
      dup_fields = Otel.API.Propagator.TextMap.Composite.fields([@trace_context, @trace_context])
      assert Enum.count(dup_fields, &(&1 == "traceparent")) == 1
    end

    test "accepts {module, opts} tuple entries alongside bare modules" do
      assert "x-fake" in Otel.API.Propagator.TextMap.Composite.fields([{@fake, %{}}])
    end
  end
end
