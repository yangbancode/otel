defmodule Otel.Trace.SpanCreatorTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
    :ok
  end

  defp start(ctx, name, opts \\ []) do
    Otel.Trace.Span.start_span(
      ctx,
      name,
      Keyword.get(opts, :limits, Otel.Trace.SpanLimits.new()),
      Keyword.delete(opts, :limits)
    )
  end

  describe "start_span — root vs child + parent validation" do
    test "no parent → root span; valid parent → child inherits trace_id and tracestate" do
      ts = Otel.Trace.TraceState.add(Otel.Trace.TraceState.new(), "vendor", "value")

      parent =
        Otel.Trace.SpanContext.new(%{
          trace_id: 123,
          span_id: 456,
          trace_flags: 1,
          tracestate: ts
        })

      ctx_with_parent = Otel.Trace.set_current_span(Otel.Ctx.new(), parent)

      {root_ctx, root} = start(Otel.Ctx.new(), "root_span")
      assert root_ctx.trace_id != 0
      assert Otel.Trace.SpanContext.valid?(root_ctx)
      assert root.name == "root_span"
      assert root.parent_span_id == nil

      {child_ctx, child} = start(ctx_with_parent, "child_span")
      assert child_ctx.trace_id == 123
      assert child_ctx.span_id != 456
      assert child_ctx.tracestate == ts
      assert child.parent_span_id == 456
    end

    test "invalid parent (zero trace_id or zero span_id) creates a root span" do
      bad_trace_id = %Otel.Trace.SpanContext{trace_id: 0, span_id: 1}
      bad_span_id = %Otel.Trace.SpanContext{trace_id: 123, span_id: 0}

      {ctx_a, _} = start(Otel.Trace.set_current_span(Otel.Ctx.new(), bad_trace_id), "n")
      {ctx_b, _} = start(Otel.Trace.set_current_span(Otel.Ctx.new(), bad_span_id), "n")

      assert ctx_a.trace_id != 0
      assert ctx_b.trace_id != 123
    end

    test "is_root option overrides a valid parent" do
      parent_ctx =
        Otel.Trace.set_current_span(
          Otel.Ctx.new(),
          Otel.Trace.SpanContext.new(%{trace_id: 123, span_id: 456, trace_flags: 1})
        )

      {ctx, span} = start(parent_ctx, "forced_root", is_root: true)
      assert ctx.trace_id != 123
      assert span.parent_span_id == nil
    end
  end

  describe "sampling decisions drive trace_flags + span emission" do
    # Spec trace/sdk.md §Sampler — record_and_sample sets the
    # sampled flag (trace_flags & 0x01) and yields a recording
    # span; drop yields no span (nil) but the SpanContext still
    # carries a freshly generated span_id (used by parents that
    # record links to dropped children).
    #
    # The hardcoded `parentbased_always_on` sampler produces:
    #   - root or sampled parent → record_and_sample
    #   - not-sampled parent     → drop
    test "root span → record_and_sample (flags=1, span emitted)" do
      {sampled_ctx, sampled} = start(Otel.Ctx.new(), "sampled")
      assert Bitwise.band(sampled_ctx.trace_flags, 1) == 1
      assert sampled.trace_flags == 1
      # `record_and_sample` 의 증거는 struct 가 생성된 것 (drop 시
      # `nil`). Storage-based `recording?/1` 검증은 `Tracer.start_span`
      # (Tracer.start_span which calls SpanStorage.insert) — see `tracer_test`.
      assert match?(%Otel.Trace.Span{}, sampled)
    end

    test "child of not-sampled parent → drop (flags=0, no span, span_id still generated)" do
      not_sampled_parent =
        Otel.Trace.SpanContext.new(%{trace_id: 123, span_id: 456, trace_flags: 0})

      ctx =
        Otel.Trace.set_current_span(Otel.Ctx.new(), not_sampled_parent)

      {dropped_ctx, dropped} = start(ctx, "dropped")
      assert Bitwise.band(dropped_ctx.trace_flags, 1) == 0
      assert dropped == nil
      assert dropped_ctx.span_id != 0
    end
  end

  describe "start_span options" do
    test "kind, attributes, start_time pass through to the span" do
      {_, span} =
        start(Otel.Ctx.new(), "span",
          kind: :server,
          attributes: %{"key" => "val"},
          start_time: 1_000_000_000
        )

      assert span.kind == :server
      assert span.attributes["key"] == "val"
      assert span.start_time == 1_000_000_000
    end

    test "start_time defaults to System.system_time(:nanosecond)" do
      before = System.system_time(:nanosecond)
      {_, span} = start(Otel.Ctx.new(), "span")
      after_time = System.system_time(:nanosecond)

      assert span.start_time in before..after_time
    end
  end

  describe "span limits" do
    test "attribute_count_limit drops excess; reports dropped_attributes_count" do
      limits = Otel.Trace.SpanLimits.new(%{attribute_count_limit: 2})

      {_, span} =
        start(Otel.Ctx.new(), "span",
          limits: limits,
          attributes: %{"a" => 1, "b" => 2, "c" => 3, "d" => 4}
        )

      assert map_size(span.attributes) == 2
      assert span.dropped_attributes_count == 2
    end

    test "attribute_value_length_limit truncates strings; :infinity skips; non-strings unchanged" do
      strict = Otel.Trace.SpanLimits.new(%{attribute_value_length_limit: 5})
      infinite = Otel.Trace.SpanLimits.new(%{attribute_value_length_limit: :infinity})
      arr_limit = Otel.Trace.SpanLimits.new(%{attribute_value_length_limit: 3})
      tight = Otel.Trace.SpanLimits.new(%{attribute_value_length_limit: 1})

      {_, sized} =
        start(Otel.Ctx.new(), "n",
          limits: strict,
          attributes: %{"key" => "hello world"}
        )

      assert String.length(sized.attributes["key"]) <= 5

      long = String.duplicate("a", 10_000)

      {_, unbounded} =
        start(Otel.Ctx.new(), "n", limits: infinite, attributes: %{"key" => long})

      assert unbounded.attributes["key"] == long

      {_, num} = start(Otel.Ctx.new(), "n", limits: tight, attributes: %{"num" => 12_345})

      assert num.attributes["num"] == 12_345

      {_, arrs} =
        start(Otel.Ctx.new(), "n",
          limits: arr_limit,
          attributes: %{"tags" => ["hello", "world"]}
        )

      assert arrs.attributes["tags"] == ["hel", "wor"]
    end

    test "value-length limit recurses into nested AnyValue maps and tagged :bytes" do
      limits = Otel.Trace.SpanLimits.new(%{attribute_value_length_limit: 5})

      {_, span} =
        start(Otel.Ctx.new(), "n",
          limits: limits,
          attributes: %{
            "envelope" => %{"name" => "abcdefghij", "nested" => %{"deep" => "wxyzabcdef"}},
            "data" => {:bytes, <<1, 2, 3, 4, 5, 6, 7>>}
          }
        )

      assert span.attributes["envelope"] == %{
               "name" => "abcde",
               "nested" => %{"deep" => "wxyza"}
             }

      assert span.attributes["data"] == {:bytes, <<1, 2, 3, 4, 5>>}
    end

    test "link_count_limit + attribute_per_link_limit + per-link value-length truncation" do
      links = [
        Otel.Trace.Link.new(%{
          context: Otel.Trace.SpanContext.new(%{trace_id: 1, span_id: 1})
        }),
        Otel.Trace.Link.new(%{
          context: Otel.Trace.SpanContext.new(%{trace_id: 2, span_id: 2})
        }),
        Otel.Trace.Link.new(%{
          context: Otel.Trace.SpanContext.new(%{trace_id: 3, span_id: 3})
        })
      ]

      {_, capped} =
        start(Otel.Ctx.new(), "n",
          limits: Otel.Trace.SpanLimits.new(%{link_count_limit: 1}),
          links: links
        )

      assert length(capped.links) == 1
      assert capped.dropped_links_count == 2
      assert %Otel.Trace.Link{} = hd(capped.links)

      links_with_attrs = [
        Otel.Trace.Link.new(%{
          context: Otel.Trace.SpanContext.new(%{trace_id: 1, span_id: 1}),
          attributes: %{"a" => 1, "b" => 2, "c" => 3, "key" => "hello world"}
        })
      ]

      {_, attr_capped} =
        start(Otel.Ctx.new(), "n",
          limits:
            Otel.Trace.SpanLimits.new(%{
              attribute_per_link_limit: 2,
              attribute_value_length_limit: 3
            }),
          links: links_with_attrs
        )

      stored = hd(attr_capped.links)
      assert map_size(stored.attributes) == 2
      assert stored.dropped_attributes_count == 2

      # Of the surviving attrs, any string value is truncated to 3 chars.
      stored.attributes
      |> Map.values()
      |> Enum.each(fn v ->
        if is_binary(v), do: assert(String.length(v) <= 3)
      end)
    end
  end
end
