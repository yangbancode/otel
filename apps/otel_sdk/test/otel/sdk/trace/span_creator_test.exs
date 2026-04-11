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
          trace_id :: Otel.API.Trace.SpanContext.trace_id(),
          links :: [{Otel.API.Trace.SpanContext.t(), map()}],
          name :: String.t(),
          kind :: Otel.API.Trace.SpanKind.t(),
          attributes :: map(),
          config :: Otel.SDK.Trace.Sampler.config()
        ) :: Otel.SDK.Trace.Sampler.sampling_result()
  @impl true
  def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    {:record_only, %{}, tracestate}
  end
end

defmodule Otel.SDK.Trace.SpanCreatorTest do
  use ExUnit.Case

  setup do
    case Otel.SDK.Trace.SpanStorage.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Otel.API.Ctx.clear()
    :ok
  end

  @always_on_sampler Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOn, %{}})
  @record_only_sampler Otel.SDK.Trace.Sampler.new(
                         {Otel.SDK.Trace.SpanCreatorTest.RecordOnlySampler, %{}}
                       )
  @always_off_sampler Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOff, %{}})
  @id_generator Otel.SDK.Trace.IdGenerator.Default

  describe "root span creation" do
    test "generates new trace_id and span_id" do
      ctx = Otel.API.Ctx.new()

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "root_span",
          @always_on_sampler,
          @id_generator,
          []
        )

      assert span_ctx.trace_id != 0
      assert span_ctx.span_id != 0
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
      assert span != nil
      assert span.name == "root_span"
      assert span.parent_span_id == nil
    end

    test "with invalid parent (trace_id 0) creates root span" do
      parent = %Otel.API.Trace.SpanContext{trace_id: 0, span_id: 1}
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, _span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "root_span",
          @always_on_sampler,
          @id_generator,
          []
        )

      assert span_ctx.trace_id != 0
    end

    test "with invalid parent (span_id 0) creates root span" do
      parent = %Otel.API.Trace.SpanContext{trace_id: 123, span_id: 0}
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, _span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "root_span",
          @always_on_sampler,
          @id_generator,
          []
        )

      assert span_ctx.trace_id != 123
    end

    test "is_root option forces root span" do
      parent = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "forced_root",
          @always_on_sampler,
          @id_generator,
          is_root: true
        )

      assert span_ctx.trace_id != 123
      assert span.parent_span_id == nil
    end
  end

  describe "child span creation" do
    test "inherits parent trace_id" do
      parent = Otel.API.Trace.SpanContext.new(123, 456, 1)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "child_span",
          @always_on_sampler,
          @id_generator,
          []
        )

      assert span_ctx.trace_id == 123
      assert span_ctx.span_id != 456
      assert span.parent_span_id == 456
    end

    test "inherits parent tracestate" do
      ts = Otel.API.Trace.TraceState.new([{"vendor", "value"}])
      parent = Otel.API.Trace.SpanContext.new(123, 456, 1, ts)
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      {span_ctx, _span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "child_span",
          @always_on_sampler,
          @id_generator,
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
          []
        )

      assert span_ctx.span_id != 0
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
          kind: :server
        )

      assert span.kind == :server
    end

    test "passes attributes to span" do
      ctx = Otel.API.Ctx.new()

      {_span_ctx, span} =
        Otel.SDK.Trace.SpanCreator.start_span(
          ctx,
          "span",
          @always_on_sampler,
          @id_generator,
          attributes: %{key: "val"}
        )

      assert span.attributes.key == "val"
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
          []
        )

      after_time = System.system_time(:nanosecond)
      assert span.start_time >= before
      assert span.start_time <= after_time
    end
  end
end
