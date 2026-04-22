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

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      traceparent = Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent")
      assert traceparent == "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    end

    test "injects tracestate when non-empty" do
      ts = Otel.API.Trace.TraceState.new() |> Otel.API.Trace.TraceState.add("vendor", "value")
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1, ts)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      tracestate = Otel.API.Propagator.TextMap.default_getter(carrier, "tracestate")
      assert tracestate == "vendor=value"
    end

    test "does not inject tracestate when empty" do
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      assert Otel.API.Propagator.TextMap.default_getter(carrier, "tracestate") == nil
    end

    test "does not inject for invalid span context" do
      ctx = Otel.API.Ctx.new()
      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)
      assert carrier == []
    end

    test "does not inject for zero trace_id" do
      span_ctx = %Otel.API.Trace.SpanContext{trace_id: 0, span_id: 456}
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)
      assert carrier == []
    end

    test "encodes trace_flags 0 as unsampled" do
      span_ctx = Otel.API.Trace.SpanContext.new(123, 456, 0)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)
      traceparent = Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent")
      assert String.ends_with?(traceparent, "-00")
    end
  end

  describe "extract/3" do
    test "extracts valid traceparent" do
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)

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

      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)
      span_ctx = Otel.API.Trace.current_span(ctx)

      assert Otel.API.Trace.TraceState.get(span_ctx.tracestate, "vendor") == "value"
    end

    test "returns original context for missing traceparent" do
      ctx = Otel.API.Ctx.new()
      result = Otel.API.Propagator.TextMap.TraceContext.extract(ctx, [], @getter)
      assert result == ctx
    end

    test "trims whitespace" do
      carrier = [{"traceparent", "  00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01  "}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
    end

    test "accepts future version with trailing forward-compat bytes" do
      # Version 01 with a trailing "-future-field" per W3C Level 2 forward-compat
      carrier = [
        {"traceparent", "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-fg00"}
      ]

      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)
      span_ctx = Otel.API.Trace.current_span(ctx)

      assert span_ctx.trace_id == 0x0AF7651916CD43DD8448EB211C80319C
      assert span_ctx.span_id == 0xB7AD6B7169203331
    end

    test "accepts future version at exactly 55 chars (no trailing, W3C L237)" do
      # W3C §Versioning L237-L238: flags "either at the end of the string or
      # followed by a dash" — a higher-version header with no extra fields
      # (exactly 55 chars) MUST still be parsable.
      carrier = [
        {"traceparent", "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}
      ]

      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)
      span_ctx = Otel.API.Trace.current_span(ctx)

      assert span_ctx.trace_id == 0x0AF7651916CD43DD8448EB211C80319C
      assert span_ctx.span_id == 0xB7AD6B7169203331
    end

    test "uppercase version rejected (W3C L83 2HEXDIGLC)" do
      # Version is specified as 2HEXDIGLC (lowercase hex). Uppercase version
      # like "FF" or "AB" must be rejected even though the ff-reserved guard
      # only excludes literal lowercase "ff".
      carrier = [
        {"traceparent", "FF-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}
      ]

      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "v00 with trailing bytes leaves ctx unchanged (W3C strict length)" do
      # v00 MUST be exactly 55 chars; any trailing bytes are invalid per W3C.
      # Extract MUST NOT throw (api-propagators.md L102) → returns ctx unchanged.
      carrier = [
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-extra"}
      ]

      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "reserved version ff leaves ctx unchanged" do
      carrier = [
        {"traceparent", "ff-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}
      ]

      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "uppercase hex in traceparent leaves ctx unchanged (W3C strict lowercase)" do
      # W3C Trace Context § 3.2.2.2 requires lowercase hex.
      carrier = [
        {"traceparent", "00-0AF7651916CD43DD8448EB211C80319C-B7AD6B7169203331-01"}
      ]

      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "all-zero trace_id leaves ctx unchanged" do
      carrier = [
        {"traceparent", "00-00000000000000000000000000000000-b7ad6b7169203331-01"}
      ]

      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "garbage traceparent leaves ctx unchanged" do
      carrier = [{"traceparent", "this is not a valid traceparent"}]

      ctx = Otel.API.Ctx.new()
      assert ctx == Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter)
    end

    test "extracts unsampled span" do
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00"}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert span_ctx.trace_flags == 0
    end

    test "handles missing tracestate gracefully" do
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      ctx = Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)

      span_ctx = Otel.API.Trace.current_span(ctx)
      assert Otel.API.Trace.TraceState.empty?(span_ctx.tracestate)
    end

    test "roundtrip inject then extract preserves context" do
      original =
        Otel.API.Trace.SpanContext.new(
          0x0AF7651916CD43DD8448EB211C80319C,
          0xB7AD6B7169203331,
          1,
          Otel.API.Trace.TraceState.new() |> Otel.API.Trace.TraceState.add("vendor", "value")
        )

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), original)
      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      new_ctx =
        Otel.API.Propagator.TextMap.TraceContext.extract(Otel.API.Ctx.new(), carrier, @getter)

      extracted = Otel.API.Trace.current_span(new_ctx)

      assert extracted.trace_id == original.trace_id
      assert extracted.span_id == original.span_id
      assert extracted.trace_flags == original.trace_flags
      assert extracted.is_remote == true
      assert Otel.API.Trace.TraceState.get(extracted.tracestate, "vendor") == "value"
    end
  end

  describe "encode_traceparent/1" do
    test "encodes a valid span context as v00 header" do
      span_ctx =
        Otel.API.Trace.SpanContext.new(0x0AF7651916CD43DD8448EB211C80319C, 0xB7AD6B7169203331, 1)

      assert Otel.API.Propagator.TextMap.TraceContext.encode_traceparent(span_ctx) ==
               "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    end

    test "encodes trace_flags 0 as '00'" do
      span_ctx = Otel.API.Trace.SpanContext.new(1, 1, 0)
      header = Otel.API.Propagator.TextMap.TraceContext.encode_traceparent(span_ctx)
      assert String.ends_with?(header, "-00")
    end

    test "preserves full flag byte (does not mask reserved bits)" do
      # W3C §Other Flags L202: outgoing vendors MUST zero unknown bits, but
      # that's the span-context producer's responsibility — this serializer
      # renders whatever byte it's given.
      span_ctx = Otel.API.Trace.SpanContext.new(1, 1, 0xFF)
      header = Otel.API.Propagator.TextMap.TraceContext.encode_traceparent(span_ctx)
      assert String.ends_with?(header, "-ff")
    end
  end

  describe "decode_traceparent/1" do
    test "parses v00 at exactly 55 chars" do
      span_ctx =
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
        )

      assert span_ctx.trace_id == 0x0AF7651916CD43DD8448EB211C80319C
      assert span_ctx.span_id == 0xB7AD6B7169203331
      assert span_ctx.trace_flags == 1
    end

    test "parses v01 at exactly 55 chars (forward-compat L237)" do
      span_ctx =
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
        )

      assert span_ctx.trace_id == 0x0AF7651916CD43DD8448EB211C80319C
      assert span_ctx.span_id == 0xB7AD6B7169203331
    end

    test "parses v01 with trailing bytes (forward-compat L238)" do
      span_ctx =
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-extra-bytes"
        )

      assert span_ctx.trace_id == 0x0AF7651916CD43DD8448EB211C80319C
      assert span_ctx.span_id == 0xB7AD6B7169203331
    end

    test "raises on v00 with trailing bytes (strict ABNF L93)" do
      assert_raise FunctionClauseError, fn ->
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-extra"
        )
      end
    end

    test "raises on version ff (reserved, L86)" do
      assert_raise FunctionClauseError, fn ->
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "ff-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
        )
      end
    end

    test "raises on uppercase version (L83 2HEXDIGLC)" do
      assert_raise MatchError, fn ->
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "AB-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
        )
      end
    end

    test "raises on uppercase hex in trace-id" do
      assert_raise MatchError, fn ->
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "00-0AF7651916CD43DD8448EB211C80319C-b7ad6b7169203331-01"
        )
      end
    end

    test "raises on all-zero trace_id" do
      assert_raise MatchError, fn ->
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "00-00000000000000000000000000000000-b7ad6b7169203331-01"
        )
      end
    end

    test "raises on all-zero span_id" do
      assert_raise MatchError, fn ->
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "00-0af7651916cd43dd8448eb211c80319c-0000000000000000-01"
        )
      end
    end
  end

  describe "lowercase_hex?/1" do
    test "accepts lowercase digits and a-f" do
      assert Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("00")
      assert Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("deadbeef")
      assert Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("0123456789abcdef")
    end

    test "rejects uppercase" do
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("FF")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("DEADBEEF")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("AbCd")
    end

    test "rejects non-hex characters" do
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("hello")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("1g")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("00-00")
    end

    test "rejects empty string" do
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("")
    end
  end
end
