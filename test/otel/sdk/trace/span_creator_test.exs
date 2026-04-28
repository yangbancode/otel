defmodule Otel.SDK.Trace.SpanCreatorTest do
  use ExUnit.Case, async: false

  defmodule RecordOnlySampler do
    @moduledoc false
    @behaviour Otel.SDK.Trace.Sampler

    @impl true
    def setup(_opts), do: []
    @impl true
    def description(_config), do: "RecordOnlySampler"
    @impl true
    def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
      tracestate =
        ctx
        |> Otel.API.Trace.current_span()
        |> Map.get(:tracestate, Otel.API.Trace.TraceState.new())

      {:record_only, %{}, tracestate}
    end
  end

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
    :ok
  end

  @always_on Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOn, %{}})
  @record_only Otel.SDK.Trace.Sampler.new({RecordOnlySampler, %{}})
  @always_off Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOff, %{}})
  @id_gen Otel.SDK.Trace.IdGenerator.Default

  defp start(ctx, name, sampler, opts \\ []) do
    Otel.SDK.Trace.Span.start_span(
      ctx,
      name,
      sampler,
      @id_gen,
      Keyword.get(opts, :limits, %Otel.SDK.Trace.SpanLimits{}),
      Keyword.delete(opts, :limits)
    )
  end

  describe "start_span — root vs child + parent validation" do
    test "no parent → root span; valid parent → child inherits trace_id and tracestate" do
      ts = Otel.API.Trace.TraceState.add(Otel.API.Trace.TraceState.new(), "vendor", "value")
      parent = Otel.API.Trace.SpanContext.new(123, 456, 1, ts)
      ctx_with_parent = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {root_ctx, root} = start(Otel.API.Ctx.new(), "root_span", @always_on)
      assert root_ctx.trace_id != 0
      assert Otel.API.Trace.SpanContext.valid?(root_ctx)
      assert root.name == "root_span"
      assert root.parent_span_id == nil

      {child_ctx, child} = start(ctx_with_parent, "child_span", @always_on)
      assert child_ctx.trace_id == 123
      assert child_ctx.span_id != 456
      assert child_ctx.tracestate == ts
      assert child.parent_span_id == 456
    end

    test "invalid parent (zero trace_id or zero span_id) creates a root span" do
      bad_trace_id = %Otel.API.Trace.SpanContext{trace_id: 0, span_id: 1}
      bad_span_id = %Otel.API.Trace.SpanContext{trace_id: 123, span_id: 0}

      {ctx_a, _} =
        start(Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), bad_trace_id), "n", @always_on)

      {ctx_b, _} =
        start(Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), bad_span_id), "n", @always_on)

      assert ctx_a.trace_id != 0
      assert ctx_b.trace_id != 123
    end

    test "is_root option overrides a valid parent" do
      parent_ctx =
        Otel.API.Trace.set_current_span(
          Otel.API.Ctx.new(),
          Otel.API.Trace.SpanContext.new(123, 456, 1)
        )

      {ctx, span} = start(parent_ctx, "forced_root", @always_on, is_root: true)
      assert ctx.trace_id != 123
      assert span.parent_span_id == nil
    end
  end

  describe "sampling decisions drive trace_flags + span emission" do
    # Spec trace/sdk.md §Sampler — record_and_sample sets the
    # sampled flag (trace_flags & 0x01) and yields a recording
    # span; record_only yields a recording span but trace_flags is
    # unsampled; drop yields no span (nil) but the SpanContext
    # still carries a freshly generated span_id (used by parents
    # that record links to dropped children).
    test "record_and_sample / record_only / drop produce the documented (flags, span) shape" do
      {sampled_ctx, sampled} = start(Otel.API.Ctx.new(), "sampled", @always_on)
      assert Bitwise.band(sampled_ctx.trace_flags, 1) == 1
      assert sampled.is_recording == true
      assert sampled.trace_flags == 1

      {record_only_ctx, record_only} = start(Otel.API.Ctx.new(), "record_only", @record_only)
      assert Bitwise.band(record_only_ctx.trace_flags, 1) == 0
      assert record_only.is_recording == true
      assert record_only.trace_flags == 0

      {dropped_ctx, dropped} = start(Otel.API.Ctx.new(), "dropped", @always_off)
      assert Bitwise.band(dropped_ctx.trace_flags, 1) == 0
      assert dropped == nil
      # span_id is generated even for dropped spans.
      assert dropped_ctx.span_id != 0
    end
  end

  describe "start_span options" do
    test "kind, attributes, start_time pass through to the span" do
      {_, span} =
        start(Otel.API.Ctx.new(), "span", @always_on,
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
      {_, span} = start(Otel.API.Ctx.new(), "span", @always_on)
      after_time = System.system_time(:nanosecond)

      assert span.start_time in before..after_time
    end
  end

  describe "span limits" do
    test "attribute_count_limit drops excess; reports dropped_attributes_count" do
      limits = %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2}

      {_, span} =
        start(Otel.API.Ctx.new(), "span", @always_on,
          limits: limits,
          attributes: %{"a" => 1, "b" => 2, "c" => 3, "d" => 4}
        )

      assert map_size(span.attributes) == 2
      assert span.dropped_attributes_count == 2
    end

    test "attribute_value_length_limit truncates strings; :infinity skips; non-strings unchanged" do
      strict = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 5}
      infinite = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: :infinity}
      arr_limit = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3}
      tight = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 1}

      {_, sized} =
        start(Otel.API.Ctx.new(), "n", @always_on,
          limits: strict,
          attributes: %{"key" => "hello world"}
        )

      assert String.length(sized.attributes["key"]) <= 5

      long = String.duplicate("a", 10_000)

      {_, unbounded} =
        start(Otel.API.Ctx.new(), "n", @always_on, limits: infinite, attributes: %{"key" => long})

      assert unbounded.attributes["key"] == long

      {_, num} =
        start(Otel.API.Ctx.new(), "n", @always_on, limits: tight, attributes: %{"num" => 12_345})

      assert num.attributes["num"] == 12_345

      {_, arrs} =
        start(Otel.API.Ctx.new(), "n", @always_on,
          limits: arr_limit,
          attributes: %{"tags" => ["hello", "world"]}
        )

      assert arrs.attributes["tags"] == ["hel", "wor"]
    end

    test "value-length limit recurses into nested AnyValue maps and tagged :bytes" do
      limits = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 5}

      {_, span} =
        start(Otel.API.Ctx.new(), "n", @always_on,
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
        %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(1, 1)},
        %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(2, 2)},
        %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(3, 3)}
      ]

      {_, capped} =
        start(Otel.API.Ctx.new(), "n", @always_on,
          limits: %Otel.SDK.Trace.SpanLimits{link_count_limit: 1},
          links: links
        )

      assert length(capped.links) == 1
      assert capped.dropped_links_count == 2
      assert %Otel.SDK.Trace.Link{} = hd(capped.links)

      links_with_attrs = [
        %Otel.API.Trace.Link{
          context: Otel.API.Trace.SpanContext.new(1, 1),
          attributes: %{"a" => 1, "b" => 2, "c" => 3, "key" => "hello world"}
        }
      ]

      {_, attr_capped} =
        start(Otel.API.Ctx.new(), "n", @always_on,
          limits: %Otel.SDK.Trace.SpanLimits{
            attribute_per_link_limit: 2,
            attribute_value_length_limit: 3
          },
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
