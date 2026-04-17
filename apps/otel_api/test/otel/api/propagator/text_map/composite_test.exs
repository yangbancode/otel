defmodule Otel.API.Propagator.TextMap.CompositeTest.FakePropagator do
  @behaviour Otel.API.Propagator.TextMap

  @impl true
  @spec inject(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          setter :: Otel.API.Propagator.TextMap.setter()
        ) :: Otel.API.Propagator.TextMap.carrier()
  def inject(_ctx, carrier, setter) do
    setter.("x-fake", "injected", carrier)
  end

  @impl true
  @spec extract(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Ctx.t()
  def extract(ctx, carrier, getter) do
    case getter.(carrier, "x-fake") do
      nil -> ctx
      value -> Otel.API.Ctx.set_value(ctx, :fake_value, value)
    end
  end

  @impl true
  @spec fields() :: [String.t()]
  def fields, do: ["x-fake"]
end

defmodule Otel.API.Propagator.TextMap.CompositeTest do
  use ExUnit.Case, async: true

  @fake Otel.API.Propagator.TextMap.CompositeTest.FakePropagator
  @trace_context Otel.API.Propagator.TraceContext

  describe "new/1" do
    test "creates composite propagator tuple" do
      {module, propagators} = Otel.API.Propagator.TextMap.Composite.new([@trace_context, @fake])
      assert module == Otel.API.Propagator.TextMap.Composite
      assert propagators == [@trace_context, @fake]
    end
  end

  describe "inject/4" do
    test "injects from all propagators in order" do
      span_ctx =
        Otel.API.Trace.SpanContext.new(
          Otel.API.Trace.TraceId.new(<<123::128>>),
          Otel.API.Trace.SpanId.new(<<456::64>>),
          1
        )

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
    end
  end

  describe "extract/4" do
    test "extracts from all propagators, threading context" do
      carrier = [
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"},
        {"x-fake", "hello"}
      ]

      ctx =
        Otel.API.Propagator.TextMap.Composite.extract(
          [@trace_context, @fake],
          Otel.API.Ctx.new(),
          carrier,
          &Otel.API.Propagator.TextMap.default_getter/2
        )

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
      assert Otel.API.Ctx.get_value(ctx, :fake_value, nil) == "hello"
    end
  end

  describe "behaviour callbacks (0-arity propagators)" do
    test "inject/3 with empty propagators" do
      ctx = Otel.API.Ctx.new()

      carrier =
        Otel.API.Propagator.TextMap.Composite.inject(
          ctx,
          [],
          &Otel.API.Propagator.TextMap.default_setter/3
        )

      assert carrier == []
    end

    test "extract/3 with empty propagators" do
      ctx = Otel.API.Ctx.new()

      result =
        Otel.API.Propagator.TextMap.Composite.extract(
          ctx,
          [],
          &Otel.API.Propagator.TextMap.default_getter/2
        )

      assert result == ctx
    end

    test "fields/0 with empty propagators" do
      assert Otel.API.Propagator.TextMap.Composite.fields() == []
    end
  end

  describe "dispatch via global registration" do
    setup do
      composite =
        Otel.API.Propagator.TextMap.Composite.new([@trace_context, @fake])

      Otel.API.Propagator.set_text_map_propagator(composite)

      on_exit(fn ->
        :persistent_term.erase(:"__otel.propagator.text_map__")
      end)

      :ok
    end

    test "inject dispatches through composite tuple" do
      span_ctx =
        Otel.API.Trace.SpanContext.new(
          Otel.API.Trace.TraceId.new(<<123::128>>),
          Otel.API.Trace.SpanId.new(<<456::64>>),
          1
        )

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.inject(ctx, [])

      keys = Enum.map(carrier, fn {k, _v} -> k end)
      assert "traceparent" in keys
      assert "x-fake" in keys
    end

    test "extract dispatches through composite tuple" do
      carrier = [
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"},
        {"x-fake", "hello"}
      ]

      ctx = Otel.API.Propagator.TextMap.extract(Otel.API.Ctx.new(), carrier)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
      assert Otel.API.Ctx.get_value(ctx, :fake_value, nil) == "hello"
    end
  end

  describe "fields/1" do
    test "returns union of all propagator fields" do
      fields = Otel.API.Propagator.TextMap.Composite.fields([@trace_context, @fake])
      assert "traceparent" in fields
      assert "tracestate" in fields
      assert "x-fake" in fields
    end

    test "handles tuple propagators in fields" do
      fields =
        Otel.API.Propagator.TextMap.Composite.fields([{@fake, %{}}])

      assert "x-fake" in fields
    end

    test "deduplicates fields" do
      fields =
        Otel.API.Propagator.TextMap.Composite.fields([@trace_context, @trace_context])

      assert Enum.count(fields, &(&1 == "traceparent")) == 1
    end
  end
end
