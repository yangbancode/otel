defmodule Otel.Trace.SpanContextTest do
  use ExUnit.Case, async: true

  @trace_id 0xFF000000000000000000000000000001
  @span_id 0xFF00000000000001

  test "default struct has all zeros, empty TraceState, is_remote false" do
    assert %Otel.Trace.SpanContext{} ==
             %Otel.Trace.SpanContext{
               trace_id: 0,
               span_id: 0,
               trace_flags: 0,
               tracestate: Otel.Trace.TraceState.new(),
               is_remote: false
             }
  end

  describe "new/4" do
    test "trace_flags and tracestate default to 0 / empty" do
      ctx = Otel.Trace.SpanContext.new(@trace_id, @span_id)

      assert ctx.trace_id == @trace_id
      assert ctx.span_id == @span_id
      assert ctx.trace_flags == 0
      assert ctx.tracestate == Otel.Trace.TraceState.new()
      assert ctx.is_remote == false
    end

    test "trace_flags and tracestate are forwarded when supplied" do
      ts = Otel.Trace.TraceState.add(Otel.Trace.TraceState.new(), "vendor", "value")
      ctx = Otel.Trace.SpanContext.new(@trace_id, @span_id, 1, ts)

      assert ctx.trace_flags == 1
      assert ctx.tracestate == ts
    end
  end

  describe "valid?/1" do
    # Spec trace/api.md L268-L271: valid iff both ids are non-zero.
    test "true only when both trace_id and span_id are non-zero" do
      assert Otel.Trace.SpanContext.valid?(Otel.Trace.SpanContext.new(@trace_id, @span_id))
    end

    test "false when either id is zero" do
      refute Otel.Trace.SpanContext.valid?(Otel.Trace.SpanContext.new(0, @span_id))
      refute Otel.Trace.SpanContext.valid?(Otel.Trace.SpanContext.new(@trace_id, 0))
      refute Otel.Trace.SpanContext.valid?(Otel.Trace.SpanContext.new(0, 0))
      refute Otel.Trace.SpanContext.valid?(%Otel.Trace.SpanContext{})
    end
  end

  describe "remote?/1" do
    # Spec trace/api.md L273-L278: true only when the SpanContext was
    # extracted from a remote parent by a Propagator.
    test "reads the is_remote field" do
      ctx = Otel.Trace.SpanContext.new(@trace_id, @span_id)
      refute Otel.Trace.SpanContext.remote?(ctx)
      assert Otel.Trace.SpanContext.remote?(%{ctx | is_remote: true})
    end
  end

  describe "id retrieval (delegates to TraceId/SpanId)" do
    # The encoding rules (lowercase hex, zero-padding, big-endian
    # bytes) are verified in TraceIdTest and SpanIdTest. Here we
    # just verify the accessor extracts the right struct field.
    setup do
      %{ctx: Otel.Trace.SpanContext.new(@trace_id, @span_id)}
    end

    test "trace_id_hex/1 forwards trace_id", %{ctx: ctx} do
      assert Otel.Trace.SpanContext.trace_id_hex(ctx) ==
               Otel.Trace.TraceId.to_hex(@trace_id)
    end

    test "span_id_hex/1 forwards span_id", %{ctx: ctx} do
      assert Otel.Trace.SpanContext.span_id_hex(ctx) == Otel.Trace.SpanId.to_hex(@span_id)
    end

    test "trace_id_bytes/1 forwards trace_id", %{ctx: ctx} do
      assert Otel.Trace.SpanContext.trace_id_bytes(ctx) ==
               Otel.Trace.TraceId.to_bytes(@trace_id)
    end

    test "span_id_bytes/1 forwards span_id", %{ctx: ctx} do
      assert Otel.Trace.SpanContext.span_id_bytes(ctx) ==
               Otel.Trace.SpanId.to_bytes(@span_id)
    end
  end
end
