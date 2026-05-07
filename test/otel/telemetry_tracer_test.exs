defmodule Otel.TelemetryTracerTest do
  # async: false — shares the global SpanStorage and OTel ctx.
  use ExUnit.Case, async: false

  setup do
    # Start the SDK with no SpanProcessor — completed spans pile
    # up in `Otel.Trace.SpanStorage` where the test can inspect
    # them via `take_completed/1` instead of being shipped out.
    Otel.TestSupport.restart_with(trace: [processors: []])
    :ok
  end

  defp start_tracer!(events) do
    start_supervised!({Otel.TelemetryTracer, events: events})
  end

  defp completed_spans do
    # Drain everything currently in storage; test then filters
    # to the spans it cares about.
    Otel.Trace.SpanStorage.take_completed(100)
  end

  defp find_span(spans, name) do
    Enum.find(spans, &(&1.name == name))
  end

  describe "start_link/1" do
    test "without :events → no-op tracer (alive, no handlers attached)" do
      pid = start_supervised!(Otel.TelemetryTracer)
      assert Process.alive?(pid)
      # No event prefixes configured → no telemetry handlers owned.
      handlers = :telemetry.list_handlers([])
      refute Enum.any?(handlers, &match?({Otel.TelemetryTracer, _, ^pid}, &1.id))
    end

    test "attaches handlers on init, detaches on terminate" do
      pid = start_tracer!([[:my_app, :detach_test]])

      attached =
        :telemetry.list_handlers([:my_app, :detach_test, :start])
        |> Enum.map(& &1.id)

      assert {Otel.TelemetryTracer, [:my_app, :detach_test, :start], pid} in attached

      # Clean shutdown via the test supervisor calls `terminate/2`,
      # which detaches the handlers.
      :ok = stop_supervised(Otel.TelemetryTracer)

      attached_after =
        :telemetry.list_handlers([:my_app, :detach_test, :start])
        |> Enum.map(& &1.id)

      refute {Otel.TelemetryTracer, [:my_app, :detach_test, :start], pid} in attached_after
    end
  end

  describe "happy path" do
    test "wraps :telemetry.span/3 → 1 OTel span with merged attributes" do
      start_tracer!([[:my_app, :add]])

      result =
        :telemetry.span(
          [:my_app, :add],
          %{a: 2, b: 3},
          fn -> {5, %{result: 5}} end
        )

      assert result == 5

      span = find_span(completed_spans(), "my_app.add")
      assert span
      # start_metadata + stop_metadata both surfaced
      assert span.attributes["a"] == 2
      assert span.attributes["b"] == 3
      assert span.attributes["result"] == 5
      # Reserved telemetry-internal keys filtered out
      refute Map.has_key?(span.attributes, "telemetry_span_context")
      refute Map.has_key?(span.attributes, "duration")
      refute Map.has_key?(span.attributes, "monotonic_time")
      refute Map.has_key?(span.attributes, "system_time")
      # Status set to :ok on normal stop
      assert span.status.code == :ok
    end

    test "span name = prefix joined by '.'" do
      start_tracer!([[:foo, :bar, :baz]])

      :telemetry.span([:foo, :bar, :baz], %{}, fn -> {:ok, %{}} end)

      assert find_span(completed_spans(), "foo.bar.baz")
    end

    test "metadata.span_kind overrides default :internal" do
      start_tracer!([[:my_app, :http_call]])

      :telemetry.span(
        [:my_app, :http_call],
        %{span_kind: :client, url: "https://x"},
        fn -> {:ok, %{}} end
      )

      span = find_span(completed_spans(), "my_app.http_call")
      assert span.kind == :client
      # span_kind itself is filtered (it's a directive, not an attribute)
      refute Map.has_key?(span.attributes, "span_kind")
    end
  end

  describe "nested spans" do
    test "inner :telemetry.span carries the outer span as parent" do
      start_tracer!([[:my_app, :outer], [:my_app, :inner]])

      :telemetry.span([:my_app, :outer], %{}, fn ->
        :telemetry.span([:my_app, :inner], %{}, fn -> {:ok, %{}} end)
        {:ok, %{}}
      end)

      spans = completed_spans()
      outer = find_span(spans, "my_app.outer")
      inner = find_span(spans, "my_app.inner")

      assert outer
      assert inner
      assert inner.parent_span_id == outer.span_id
      assert inner.trace_id == outer.trace_id
    end

    test "with_span/4 around :telemetry.span — both APIs share ctx" do
      start_tracer!([[:my_app, :inner]])

      Otel.Trace.with_span("outer_via_with_span", fn _ ->
        :telemetry.span([:my_app, :inner], %{}, fn -> {:ok, %{}} end)
      end)

      spans = completed_spans()
      outer = find_span(spans, "outer_via_with_span")
      inner = find_span(spans, "my_app.inner")

      assert outer
      assert inner
      assert inner.parent_span_id == outer.span_id
      assert inner.trace_id == outer.trace_id
    end
  end

  describe "exception path" do
    test "raised exception → ERROR status + exception event recorded" do
      start_tracer!([[:my_app, :crash]])

      assert_raise RuntimeError, "boom", fn ->
        :telemetry.span([:my_app, :crash], %{user_id: 7}, fn ->
          raise "boom"
        end)
      end

      span = find_span(completed_spans(), "my_app.crash")
      assert span
      assert span.status.code == :error
      assert span.status.description == "boom"
      # start_metadata still surfaces on the failed span
      assert span.attributes["user_id"] == 7
      # `record_exception/4` adds an exception event to the span
      assert Enum.any?(span.events, &(&1.name == "exception"))
    end

    test ":exit class produces ERROR status with reason in description" do
      start_tracer!([[:my_app, :gone]])

      catch_exit(
        :telemetry.span([:my_app, :gone], %{}, fn ->
          exit(:crashed)
        end)
      )

      span = find_span(completed_spans(), "my_app.gone")
      assert span
      assert span.status.code == :error
      assert span.status.description =~ "exit"
      assert span.status.description =~ "crashed"
    end
  end

  describe "process boundary" do
    test "orphan :stop without matching :start is a no-op (no crash)" do
      pid = start_tracer!([[:my_app, :weird]])

      # Hand-emit a :stop with a fabricated context ref — the
      # bridge has no matching start, should silently ignore.
      :telemetry.execute(
        [:my_app, :weird, :stop],
        %{duration: 0},
        %{telemetry_span_context: make_ref()}
      )

      assert Process.alive?(pid)
      refute find_span(completed_spans(), "my_app.weird")
    end
  end
end
