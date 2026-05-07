defmodule Otel.E2E.TelemetryTracerTest do
  @moduledoc """
  E2E coverage for the `:telemetry.span/3` → OTel Trace bridge
  (`Otel.TelemetryTracer`) against Tempo.

  Each scenario starts a tracer with one or more event prefixes
  whose paths carry the per-test `e2e_id`, calls
  `:telemetry.span/3`, then asserts the resulting span lands in
  Tempo **and** carries the expected name / attributes / parent
  link / status.

  Tracking matrix: `.claude/docs/e2e.md` §TelemetryTracer.
  """

  use Otel.E2E.Case, async: false

  describe "telemetry.span → OTel Trace → Tempo" do
    test "1: Single span — name from prefix, start+stop attrs merged",
         %{e2e_id: e2e_id} do
      prefix = [:"telem_tracer_1_#{e2e_id}", :add]
      start_tracer!([prefix])

      result =
        :telemetry.span(prefix, %{a: 2, b: 3, "e2e.id": e2e_id}, fn ->
          {5, %{result: 5}}
        end)

      assert result == 5
      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == "telem_tracer_1_#{e2e_id}.add"
      assert attribute(span, "a") == 2
      assert attribute(span, "b") == 3
      assert attribute(span, "result") == 5
      assert span["status"]["code"] == "STATUS_CODE_OK"
    end

    test "2: Nested span carries parent_span_id + same trace_id",
         %{e2e_id: e2e_id} do
      outer = [:"telem_tracer_2_#{e2e_id}", :outer]
      inner = [:"telem_tracer_2_#{e2e_id}", :inner]
      start_tracer!([outer, inner])

      :telemetry.span(outer, %{"e2e.id": e2e_id}, fn ->
        :telemetry.span(inner, %{"e2e.id": e2e_id}, fn -> {:ok, %{}} end)
        {:ok, %{}}
      end)

      flush()

      spans = trace_spans(e2e_id)
      outer_span = Enum.find(spans, &(&1["name"] =~ ~r/\.outer$/))
      inner_span = Enum.find(spans, &(&1["name"] =~ ~r/\.inner$/))

      assert outer_span
      assert inner_span
      assert inner_span["traceId"] == outer_span["traceId"]
      assert inner_span["parentSpanId"] == outer_span["spanId"]
    end

    test "3: Exception → ERROR status + recorded exception event",
         %{e2e_id: e2e_id} do
      prefix = [:"telem_tracer_3_#{e2e_id}", :crash]
      start_tracer!([prefix])

      assert_raise RuntimeError, "boom-#{e2e_id}", fn ->
        :telemetry.span(prefix, %{"e2e.id": e2e_id}, fn ->
          raise "boom-#{e2e_id}"
        end)
      end

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["status"]["code"] == "STATUS_CODE_ERROR"
      assert span["status"]["message"] == "boom-#{e2e_id}"
      assert Enum.any?(span["events"] || [], &(&1["name"] == "exception"))
    end

    test "4: span_kind metadata override flows through to Tempo",
         %{e2e_id: e2e_id} do
      prefix = [:"telem_tracer_4_#{e2e_id}", :http]
      start_tracer!([prefix])

      :telemetry.span(prefix, %{span_kind: :client, "e2e.id": e2e_id}, fn ->
        {:ok, %{}}
      end)

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["kind"] == "SPAN_KIND_CLIENT"
      # `span_kind` is a directive, not a user attribute.
      assert attribute(span, "span_kind") == nil
    end

    test "5: :telemetry.span inside with_span/4 carries with_span as parent",
         %{e2e_id: e2e_id} do
      inner_prefix = [:"telem_tracer_5_#{e2e_id}", :inner]
      start_tracer!([inner_prefix])

      Otel.Trace.with_span(
        "telem_tracer_5_outer_#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          :telemetry.span(inner_prefix, %{"e2e.id": e2e_id}, fn -> {:ok, %{}} end)
        end
      )

      flush()

      spans = trace_spans(e2e_id)
      outer = Enum.find(spans, &(&1["name"] == "telem_tracer_5_outer_#{e2e_id}"))
      inner = Enum.find(spans, &(&1["name"] =~ ~r/\.inner$/))

      assert outer
      assert inner
      assert inner["traceId"] == outer["traceId"]
      assert inner["parentSpanId"] == outer["spanId"]
    end

    test "6: multiple event prefixes registered to one tracer",
         %{e2e_id: e2e_id} do
      a_prefix = [:"telem_tracer_6_#{e2e_id}", :a]
      b_prefix = [:"telem_tracer_6_#{e2e_id}", :b]
      start_tracer!([a_prefix, b_prefix])

      :telemetry.span(a_prefix, %{"e2e.id": e2e_id}, fn -> {:ok, %{}} end)
      :telemetry.span(b_prefix, %{"e2e.id": e2e_id}, fn -> {:ok, %{}} end)

      flush()

      spans = trace_spans(e2e_id)
      a_span = Enum.find(spans, &(&1["name"] =~ ~r/\.a$/))
      b_span = Enum.find(spans, &(&1["name"] =~ ~r/\.b$/))

      assert a_span
      assert b_span
      # Independent traces — no implicit parent between sibling
      # `:telemetry.span` calls in the same process at the top level.
      assert a_span["traceId"] != b_span["traceId"]
    end
  end

  # ---- helpers ----

  defp start_tracer!(events) do
    pid = start_supervised!({Otel.TelemetryTracer, events: events})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    pid
  end

  defp trace_spans(e2e_id) do
    {:ok, traces} = poll(Tempo.search(e2e_id))

    Enum.flat_map(traces, fn %{"traceID" => trace_id} ->
      {:ok, body} = HTTP.get(Tempo.get_trace(trace_id))
      {:ok, %{"batches" => batches}} = Jason.decode(body)

      Enum.flat_map(batches, fn b ->
        Enum.flat_map(b["scopeSpans"] || [], &(&1["spans"] || []))
      end)
    end)
  end

  defp attribute(span, key), do: Tempo.attribute(span, key)
end
