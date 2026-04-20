defmodule Otel.API.Propagator.TextMap.TraceContextTest do
  use ExUnit.Case, async: true

  @setter &Otel.API.Propagator.TextMap.default_setter/3
  @getter &Otel.API.Propagator.TextMap.default_getter/2

  describe "fields/0" do
    test "returns traceparent and tracestate" do
      assert Otel.API.Propagator.TextMap.TraceContext.fields() == ["traceparent", "tracestate"]
    end
  end

  describe "inject/3" do
    test "injects traceparent for valid span" do
      span_ctx =
        Otel.API.Trace.SpanContext.new(0x0AF7651916CD43DD8448EB211C80319C, 0xB7AD6B7169203331, 1)

      ctx = Otel.API.Trace.set_current_span(%{}, span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      traceparent = Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent")
      assert traceparent == "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    end

    test "injects tracestate when non-empty" do
      ts = Otel.API.Trace.TraceState.new() |> Otel.API.Trace.TraceState.add("vendor", "value")
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1, ts)
      ctx = Otel.API.Trace.set_current_span(%{}, span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      tracestate = Otel.API.Propagator.TextMap.default_getter(carrier, "tracestate")
      assert tracestate == "vendor=value"
    end

    test "does not inject tracestate when empty" do
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(%{}, span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      assert Otel.API.Propagator.TextMap.default_getter(carrier, "tracestate") == nil
    end

    test "does not inject for invalid span context" do
      ctx = %{}
      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)
      assert carrier == []
    end

    test "does not inject for zero trace_id" do
      span_ctx = %Otel.API.Trace.SpanContext{trace_id: 0, span_id: 456}
      ctx = Otel.API.Trace.set_current_span(%{}, span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)
      assert carrier == []
    end

    test "encodes trace_flags 0 as unsampled" do
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 0)
      ctx = Otel.API.Trace.set_current_span(%{}, span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)
      traceparent = Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent")
      assert String.ends_with?(traceparent, "-00")
    end
  end

  describe "extract/3" do
    test "extracts valid traceparent" do
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(%{}, carrier, @getter)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert span_ctx.trace_id == 0x0AF7651916CD43DD8448EB211C80319C
      assert span_ctx.span_id == 0xB7AD6B7169203331
      assert span_ctx.trace_flags == 1
      assert span_ctx.is_remote == true
    end

    test "extracts tracestate" do
      carrier = [
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"},
        {"tracestate", "vendor=value"}
      ]

      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(%{}, carrier, @getter)
      span_ctx = Otel.API.Trace.current_span(ctx)

      assert Otel.API.Trace.TraceState.get(span_ctx.tracestate, "vendor") == "value"
    end

    test "returns original context for missing traceparent" do
      ctx = %{}
      result = Otel.API.Propagator.TextMap.TraceContext.extract(ctx, [], @getter)
      assert result == ctx
    end

    test "trims whitespace" do
      carrier = [{"traceparent", "  00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01  "}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(%{}, carrier, @getter)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
    end

    test "accepts future version with trailing forward-compat bytes" do
      # Version 01 with a trailing "-future-field" per W3C Level 2 forward-compat
      carrier = [
        {"traceparent", "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-fg00"}
      ]

      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(%{}, carrier, @getter)
      span_ctx = Otel.API.Trace.current_span(ctx)

      assert span_ctx.trace_id == 0x0AF7651916CD43DD8448EB211C80319C
      assert span_ctx.span_id == 0xB7AD6B7169203331
    end

    test "v00 with trailing bytes leaves ctx unchanged (W3C strict length)" do
      # v00 MUST be exactly 55 chars; any trailing bytes are invalid per W3C.
      # Extract MUST NOT throw (api-propagators.md L102) → returns ctx unchanged.
      carrier = [
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-extra"}
      ]

      ctx = %{}
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "reserved version ff leaves ctx unchanged" do
      carrier = [
        {"traceparent", "ff-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}
      ]

      ctx = %{}
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "uppercase hex in traceparent leaves ctx unchanged (W3C strict lowercase)" do
      # W3C Trace Context § 3.2.2.2 requires lowercase hex.
      carrier = [
        {"traceparent", "00-0AF7651916CD43DD8448EB211C80319C-B7AD6B7169203331-01"}
      ]

      ctx = %{}
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "all-zero trace_id leaves ctx unchanged" do
      carrier = [
        {"traceparent", "00-00000000000000000000000000000000-b7ad6b7169203331-01"}
      ]

      ctx = %{}
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "garbage traceparent leaves ctx unchanged" do
      carrier = [{"traceparent", "this is not a valid traceparent"}]

      ctx = %{}
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "extracts unsampled span" do
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00"}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(%{}, carrier, @getter)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert span_ctx.trace_flags == 0
      refute Otel.API.Trace.SpanContext.sampled?(span_ctx)
    end

    test "handles missing tracestate gracefully" do
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(%{}, carrier, @getter)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert Otel.API.Trace.TraceState.size(span_ctx.tracestate) == 0
    end

    test "roundtrip inject then extract preserves context" do
      original =
        Otel.API.Trace.SpanContext.new(
          0x0AF7651916CD43DD8448EB211C80319C,
          0xB7AD6B7169203331,
          1,
          Otel.API.Trace.TraceState.new() |> Otel.API.Trace.TraceState.add("vendor", "value")
        )

      ctx = Otel.API.Trace.set_current_span(%{}, original)
      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      new_ctx =
        Otel.API.Propagator.TextMap.TraceContext.extract(%{}, carrier, @getter)

      extracted = Otel.API.Trace.current_span(new_ctx)

      assert extracted.trace_id == original.trace_id
      assert extracted.span_id == original.span_id
      assert extracted.trace_flags == original.trace_flags
      assert extracted.is_remote == true
      assert Otel.API.Trace.TraceState.get(extracted.tracestate, "vendor") == "value"
    end
  end
end
