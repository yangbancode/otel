defmodule Otel.API.Propagator.TextMap.TraceContextTest do
  use ExUnit.Case, async: true

  @setter &Otel.API.Propagator.TextMap.default_setter/3
  @getter &Otel.API.Propagator.TextMap.default_getter/2

  @valid_trace_id 0x0AF7651916CD43DD8448EB211C80319C
  @valid_span_id 0xB7AD6B7169203331
  @canonical_traceparent "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

  test ~s|fields/0 returns ["traceparent", "tracestate"]| do
    assert Otel.API.Propagator.TextMap.TraceContext.fields() == ["traceparent", "tracestate"]
  end

  describe "inject/3" do
    test "writes traceparent (and tracestate when non-empty) for a valid span" do
      ts = Otel.Trace.TraceState.add(Otel.Trace.TraceState.new(), "vendor", "value")
      span_ctx = Otel.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 1, ts)
      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      assert Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent") ==
               @canonical_traceparent

      assert Otel.API.Propagator.TextMap.default_getter(carrier, "tracestate") == "vendor=value"
    end

    test "omits tracestate when empty; encodes trace_flags 0 as -00" do
      span_ctx = Otel.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0)
      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), span_ctx)

      carrier = Otel.API.Propagator.TextMap.TraceContext.inject(ctx, [], @setter)

      traceparent = Otel.API.Propagator.TextMap.default_getter(carrier, "traceparent")
      assert String.ends_with?(traceparent, "-00")
      assert Otel.API.Propagator.TextMap.default_getter(carrier, "tracestate") == nil
    end

    test "no-op when there is no valid span in the context" do
      assert Otel.API.Propagator.TextMap.TraceContext.inject(Otel.Ctx.new(), [], @setter) ==
               []

      span_ctx = %Otel.Trace.SpanContext{trace_id: 0, span_id: @valid_span_id}
      bad_ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), span_ctx)

      assert Otel.API.Propagator.TextMap.TraceContext.inject(bad_ctx, [], @setter) == []
    end
  end

  describe "extract/3 — valid traceparent" do
    test "extracts trace_id, span_id, trace_flags, sets is_remote: true" do
      carrier = [{"traceparent", @canonical_traceparent}]

      ctx =
        Otel.API.Propagator.TextMap.TraceContext.extract(Otel.Ctx.new(), carrier, @getter)

      span_ctx = Otel.Trace.current_span(ctx)

      assert span_ctx.trace_id == @valid_trace_id
      assert span_ctx.span_id == @valid_span_id
      assert span_ctx.trace_flags == 1
      assert span_ctx.is_remote == true
    end

    test "merges tracestate; tolerates whitespace; extracts unsampled" do
      carrier = [
        {"traceparent", "  00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00  "},
        {"tracestate", "vendor=value"}
      ]

      ctx =
        Otel.API.Propagator.TextMap.TraceContext.extract(Otel.Ctx.new(), carrier, @getter)

      span_ctx = Otel.Trace.current_span(ctx)

      assert span_ctx.trace_flags == 0
      assert Otel.Trace.TraceState.get(span_ctx.tracestate, "vendor") == "value"
    end

    # W3C §Versioning L237-L238: forward-compat. v01 with or without
    # trailing fields MUST parse successfully on the leading parts.
    test "accepts higher version with optional trailing forward-compat bytes" do
      bare = [{"traceparent", "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]

      with_extra = [
        {"traceparent", "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-fg00"}
      ]

      for carrier <- [bare, with_extra] do
        span_ctx =
          Otel.API.Propagator.TextMap.TraceContext.extract(Otel.Ctx.new(), carrier, @getter)
          |> Otel.Trace.current_span()

        assert span_ctx.trace_id == @valid_trace_id
        assert span_ctx.span_id == @valid_span_id
      end
    end
  end

  # Spec api-propagators.md L102: extract MUST NOT throw on parse
  # failure; it returns the original Context unchanged.
  describe "extract/3 — invalid traceparent leaves Context unchanged" do
    setup do
      %{ctx: Otel.Ctx.new()}
    end

    test "missing header", %{ctx: ctx} do
      assert Otel.API.Propagator.TextMap.TraceContext.extract(ctx, [], @getter) == ctx
    end

    test "uppercase version (W3C L83 2HEXDIGLC)", %{ctx: ctx} do
      carrier = [{"traceparent", "FF-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      assert Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter) == ctx
    end

    test "reserved version ff (W3C L86)", %{ctx: ctx} do
      carrier = [{"traceparent", "ff-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      assert Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter) == ctx
    end

    test "uppercase hex in trace_id / span_id (W3C §3.2.2.2)", %{ctx: ctx} do
      carrier = [{"traceparent", "00-0AF7651916CD43DD8448EB211C80319C-B7AD6B7169203331-01"}]
      assert Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter) == ctx
    end

    test "all-zero trace_id (invalid sentinel)", %{ctx: ctx} do
      carrier = [{"traceparent", "00-00000000000000000000000000000000-b7ad6b7169203331-01"}]
      assert Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter) == ctx
    end

    test "v00 with trailing bytes (strict ABNF L93)", %{ctx: ctx} do
      carrier = [
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-extra"}
      ]

      assert Otel.API.Propagator.TextMap.TraceContext.extract(ctx, carrier, @getter) == ctx
    end

    test "garbage bytes", %{ctx: ctx} do
      assert Otel.API.Propagator.TextMap.TraceContext.extract(
               ctx,
               [{"traceparent", "this is not a valid traceparent"}],
               @getter
             ) == ctx
    end
  end

  test "inject + extract round-trip preserves trace_id, span_id, flags, tracestate" do
    ts = Otel.Trace.TraceState.add(Otel.Trace.TraceState.new(), "vendor", "value")
    original = Otel.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 1, ts)

    carrier =
      Otel.Trace.set_current_span(Otel.Ctx.new(), original)
      |> Otel.API.Propagator.TextMap.TraceContext.inject([], @setter)

    extracted =
      Otel.API.Propagator.TextMap.TraceContext.extract(Otel.Ctx.new(), carrier, @getter)
      |> Otel.Trace.current_span()

    assert extracted.trace_id == original.trace_id
    assert extracted.span_id == original.span_id
    assert extracted.trace_flags == original.trace_flags
    assert extracted.is_remote == true
    assert Otel.Trace.TraceState.get(extracted.tracestate, "vendor") == "value"
  end

  describe "encode_traceparent/1" do
    test "encodes a valid SpanContext into the v00 wire format" do
      span_ctx = Otel.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 1)

      assert Otel.API.Propagator.TextMap.TraceContext.encode_traceparent(span_ctx) ==
               @canonical_traceparent
    end

    # W3C §Other Flags L200-L202 MUST: reserved bits MUST be set to
    # zero on serialise. Defined bits are sampled (0x01) + random (0x02).
    test "masks reserved trace_flags bits to zero" do
      assert "00-00000000000000000000000000000001-0000000000000001-03" ==
               Otel.API.Propagator.TextMap.TraceContext.encode_traceparent(
                 Otel.Trace.SpanContext.new(1, 1, 0xFF)
               )

      # Only reserved bits set → wire byte is 00.
      assert "00-00000000000000000000000000000001-0000000000000001-00" ==
               Otel.API.Propagator.TextMap.TraceContext.encode_traceparent(
                 Otel.Trace.SpanContext.new(1, 1, 0xF0)
               )
    end
  end

  describe "decode_traceparent/1" do
    test "parses v00 (55 chars) and v01 (with or without trailing fields)" do
      v00 =
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
        )

      v01 =
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
        )

      v01_extra =
        Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(
          "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-extra-bytes"
        )

      for span_ctx <- [v00, v01, v01_extra] do
        assert span_ctx.trace_id == @valid_trace_id
        assert span_ctx.span_id == @valid_span_id
      end

      assert v00.trace_flags == 1
    end

    # decode_traceparent is the strict (raising) variant — extract/3
    # is the soft variant that catches and returns ctx unchanged.
    # Each rejected shape raises FunctionClauseError or MatchError;
    # we only assert "any rejection" since the precise exception is
    # an implementation detail of the parser pattern.
    test "raises on every shape extract/3 would silently reject" do
      reject = [
        # v00 with trailing bytes (strict ABNF)
        "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-extra",
        # reserved version ff
        "ff-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
        # uppercase version
        "AB-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
        # uppercase hex
        "00-0AF7651916CD43DD8448EB211C80319C-b7ad6b7169203331-01",
        # all-zero trace_id
        "00-00000000000000000000000000000000-b7ad6b7169203331-01",
        # all-zero span_id
        "00-0af7651916cd43dd8448eb211c80319c-0000000000000000-01"
      ]

      for header <- reject do
        raised? =
          try do
            Otel.API.Propagator.TextMap.TraceContext.decode_traceparent(header)
            false
          rescue
            _ -> true
          end

        assert raised?, "expected #{header} to raise but it did not"
      end
    end
  end

  describe "lowercase_hex?/1" do
    test "true for lowercase digits + a-f" do
      assert Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("00")
      assert Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("deadbeef")
      assert Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("0123456789abcdef")
    end

    test "false for uppercase, non-hex chars, and empty string" do
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("FF")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("AbCd")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("hello")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("1g")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("00-00")
      refute Otel.API.Propagator.TextMap.TraceContext.lowercase_hex?("")
    end
  end
end
