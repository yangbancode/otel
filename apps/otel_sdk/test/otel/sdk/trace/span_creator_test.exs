defmodule Otel.SDK.Trace.SpanCreatorTest.RecordOnlySampler do
  @behaviour Otel.SDK.Trace.Sampler

  @spec setup(opts :: Otel.SDK.Trace.Sampler.opts()) :: Otel.SDK.Trace.Sampler.config()
  @impl true
  def setup(_opts), do: []

  @spec description(config :: Otel.SDK.Trace.Sampler.config()) ::
          Otel.SDK.Trace.Sampler.description()
  @impl true
  def description(_config), do: "RecordOnlySampler"

  @spec should_sample(
          ctx :: Otel.API.Ctx.t(),
          trace_id :: Otel.API.Trace.TraceId.t(),
          links :: [{Otel.API.Trace.SpanContext.t(), [Otel.API.Common.Attribute.t()]}],
          name :: String.t(),
          kind :: Otel.API.Trace.SpanKind.t(),
          attributes :: [Otel.API.Common.Attribute.t()],
          config :: Otel.SDK.Trace.Sampler.config()
        ) :: Otel.SDK.Trace.Sampler.sampling_result()
  @impl true
  def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    {:record_only, [], tracestate}
  end
end

defmodule Otel.SDK.Trace.SpanCreatorTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  @always_on_sampler Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOn, %{}})
  @record_only_sampler Otel.SDK.Trace.Sampler.new(
                         {Otel.SDK.Trace.SpanCreatorTest.RecordOnlySampler, %{}}
                       )
  @always_off_sampler Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOff, %{}})
  @id_generator Otel.SDK.Trace.IdGenerator.Default
  @span_limits %Otel.SDK.Trace.SpanLimits{}

  @trace_id_123 Otel.API.Trace.TraceId.new(<<123::128>>)
  @span_id_456 Otel.API.Trace.SpanId.new(<<456::64>>)

  describe "root span creation" do
    test "generates new trace_id and span_id" do
      ctx = Otel.API.Ctx.new()

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "root_span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          []
        )

      assert Otel.API.Trace.TraceId.valid?(span_ctx.trace_id)
      assert Otel.API.Trace.SpanId.valid?(span_ctx.span_id)
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
      assert span != nil
      assert span.name == "root_span"
      assert span.parent_span_id == nil
    end

    test "with invalid parent (trace_id 0) creates root span" do
      parent = %Otel.API.Trace.SpanContext{
        trace_id: Otel.API.Trace.TraceId.invalid(),
        span_id: Otel.API.Trace.SpanId.new(<<1::64>>)
      }

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, _span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "root_span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          []
        )

      assert Otel.API.Trace.TraceId.valid?(span_ctx.trace_id)
    end

    test "with invalid parent (span_id 0) creates root span" do
      parent = %Otel.API.Trace.SpanContext{
        trace_id: @trace_id_123,
        span_id: Otel.API.Trace.SpanId.invalid()
      }

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, _span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "root_span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          []
        )

      assert span_ctx.trace_id != @trace_id_123
    end

    test "is_root option forces root span" do
      parent = Otel.API.Trace.SpanContext.new(@trace_id_123, @span_id_456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "forced_root",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          is_root: true
        )

      assert span_ctx.trace_id != @trace_id_123
      assert span.parent_span_id == nil
    end
  end

  describe "child span creation" do
    test "inherits parent trace_id" do
      parent = Otel.API.Trace.SpanContext.new(@trace_id_123, @span_id_456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "child_span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          []
        )

      assert span_ctx.trace_id == @trace_id_123
      assert span_ctx.span_id != @span_id_456
      assert span.parent_span_id == @span_id_456
    end

    test "inherits parent tracestate" do
      ts = Otel.API.Trace.TraceState.new([{"vendor", "value"}])
      parent = Otel.API.Trace.SpanContext.new(@trace_id_123, @span_id_456, 1, ts)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, _span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "child_span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          []
        )

      # AlwaysOn sampler passes through tracestate
      assert span_ctx.tracestate == ts
    end
  end

  describe "sampling decisions" do
    test "record_and_sample sets trace_flags=1 and returns span" do
      ctx = Otel.API.Ctx.new()

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "sampled",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          []
        )

      assert Otel.API.Trace.SpanContext.sampled?(span_ctx)
      assert span != nil
      assert span.is_recording == true
      assert span.trace_flags == 1
    end

    test "record_only sets trace_flags=0 but returns span" do
      ctx = Otel.API.Ctx.new()

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "record_only",
          @record_only_sampler,
          @id_generator,
          @span_limits,
          []
        )

      refute Otel.API.Trace.SpanContext.sampled?(span_ctx)
      assert span != nil
      assert span.is_recording == true
      assert span.trace_flags == 0
    end

    test "drop sets trace_flags=0 and returns nil span" do
      ctx = Otel.API.Ctx.new()

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "dropped",
          @always_off_sampler,
          @id_generator,
          @span_limits,
          []
        )

      refute Otel.API.Trace.SpanContext.sampled?(span_ctx)
      assert span == nil
    end

    test "span_id is generated even for dropped spans" do
      ctx = Otel.API.Ctx.new()

      {span_ctx, _span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "dropped",
          @always_off_sampler,
          @id_generator,
          @span_limits,
          []
        )

      assert Otel.API.Trace.SpanId.valid?(span_ctx.span_id)
    end
  end

  describe "span options" do
    test "passes kind to span" do
      ctx = Otel.API.Ctx.new()

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "server_span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          kind: :server
        )

      assert span.kind == :server
    end

    test "passes attributes to span" do
      ctx = Otel.API.Ctx.new()

      attrs = [
        Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("val"))
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          attributes: attrs
        )

      assert Enum.find(span.attributes, &(&1.key == "key")).value ==
               Otel.API.Common.AnyValue.string("val")
    end

    test "passes custom start_time" do
      ctx = Otel.API.Ctx.new()
      ts = 1_000_000_000

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          start_time: ts
        )

      assert span.start_time == ts
    end

    test "defaults to current time for start_time" do
      ctx = Otel.API.Ctx.new()
      before = System.system_time(:nanosecond)

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          @span_limits,
          []
        )

      after_time = System.system_time(:nanosecond)
      assert span.start_time >= before
      assert span.start_time <= after_time
    end
  end

  describe "span limits" do
    test "enforces attribute_count_limit" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2}

      attrs = [
        Otel.API.Common.Attribute.new("a", Otel.API.Common.AnyValue.int(1)),
        Otel.API.Common.Attribute.new("b", Otel.API.Common.AnyValue.int(2)),
        Otel.API.Common.Attribute.new("c", Otel.API.Common.AnyValue.int(3)),
        Otel.API.Common.Attribute.new("d", Otel.API.Common.AnyValue.int(4))
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          attributes: attrs
        )

      assert length(span.attributes) <= 2
    end

    test "enforces attribute_value_length_limit" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 5}

      attrs = [
        Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("hello world"))
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          attributes: attrs
        )

      value = Enum.find(span.attributes, &(&1.key == "key")).value
      assert String.length(value.value) <= 5
    end

    test "infinity value length limit does not truncate" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: :infinity}
      long_value = String.duplicate("a", 10_000)

      attrs = [
        Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string(long_value))
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          attributes: attrs
        )

      assert Enum.find(span.attributes, &(&1.key == "key")).value.value == long_value
    end

    test "non-string values are not truncated" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 1}

      attrs = [
        Otel.API.Common.Attribute.new("num", Otel.API.Common.AnyValue.int(12_345))
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          attributes: attrs
        )

      assert Enum.find(span.attributes, &(&1.key == "num")).value.value == 12_345
    end

    test "truncates strings inside arrays" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3}

      attrs = [
        Otel.API.Common.Attribute.new(
          "tags",
          Otel.API.Common.AnyValue.array([
            Otel.API.Common.AnyValue.string("hello"),
            Otel.API.Common.AnyValue.string("world")
          ])
        )
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          attributes: attrs
        )

      array_value = Enum.find(span.attributes, &(&1.key == "tags")).value

      assert Enum.map(array_value.value, & &1.value) == ["hel", "wor"]
    end

    test "enforces link_count_limit" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{link_count_limit: 1}

      links = [
        {Otel.API.Trace.SpanContext.new(
           Otel.API.Trace.TraceId.new(<<1::128>>),
           Otel.API.Trace.SpanId.new(<<1::64>>)
         ), []},
        {Otel.API.Trace.SpanContext.new(
           Otel.API.Trace.TraceId.new(<<2::128>>),
           Otel.API.Trace.SpanId.new(<<2::64>>)
         ), []}
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          links: links
        )

      assert length(span.links) == 1
    end

    test "enforces attribute_per_link_limit at creation" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{attribute_per_link_limit: 1}

      link_attrs = [
        Otel.API.Common.Attribute.new("a", Otel.API.Common.AnyValue.int(1)),
        Otel.API.Common.Attribute.new("b", Otel.API.Common.AnyValue.int(2)),
        Otel.API.Common.Attribute.new("c", Otel.API.Common.AnyValue.int(3))
      ]

      links = [
        {Otel.API.Trace.SpanContext.new(
           Otel.API.Trace.TraceId.new(<<1::128>>),
           Otel.API.Trace.SpanId.new(<<1::64>>)
         ), link_attrs}
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          links: links
        )

      {_ctx, attrs} = hd(span.links)
      assert length(attrs) == 1
    end

    test "truncates link attribute values at creation" do
      ctx = Otel.API.Ctx.new()
      limits = %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3}

      link_attrs = [
        Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("hello world"))
      ]

      links = [
        {Otel.API.Trace.SpanContext.new(
           Otel.API.Trace.TraceId.new(<<1::128>>),
           Otel.API.Trace.SpanId.new(<<1::64>>)
         ), link_attrs}
      ]

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          limits,
          links: links
        )

      {_ctx, attrs} = hd(span.links)
      assert Enum.find(attrs, &(&1.key == "key")).value.value == "hel"
    end
  end
end
