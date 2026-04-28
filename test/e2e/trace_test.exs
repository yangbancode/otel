defmodule Otel.E2E.TraceTest do
  @moduledoc """
  E2E coverage for `Otel.API.Trace` against Tempo.

  Each scenario emits a span (or spans) tagged with the test's
  unique `e2e.id`, force-flushes, locates the trace(s) by tag,
  fetches the full OTLP-shaped JSON, and asserts on the relevant
  detail.

  Tracking matrix: `docs/e2e.md` §Trace.
  """

  use Otel.E2E.Case, async: false

  describe "lifecycle" do
    test "1: single span via with_span lands with the configured name", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      name = "scenario-1-#{e2e_id}"

      Otel.API.Trace.with_span(
        tracer,
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == name
    end

    test "2: manual start_span + end_span lands the same span", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      name = "scenario-2-#{e2e_id}"

      span_ctx =
        Otel.API.Trace.start_span(tracer, name, attributes: %{"e2e.id" => e2e_id})

      Otel.API.Trace.Span.end_span(span_ctx)

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == name
    end

    test "3: start_span/4 with explicit parent context links the child to that parent",
         %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      parent_name = "parent-3-#{e2e_id}"
      child_name = "child-3-#{e2e_id}"

      parent_ctx =
        Otel.API.Trace.start_span(tracer, parent_name, attributes: %{"e2e.id" => e2e_id})

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent_ctx)

      child_ctx =
        Otel.API.Trace.start_span(ctx, tracer, child_name, attributes: %{"e2e.id" => e2e_id})

      Otel.API.Trace.Span.end_span(child_ctx)
      Otel.API.Trace.Span.end_span(parent_ctx)

      flush()

      spans = trace_spans(e2e_id)
      parent = Enum.find(spans, &(&1["name"] == parent_name))
      child = Enum.find(spans, &(&1["name"] == child_name))

      assert parent && child
      assert child["parentSpanId"] == parent["spanId"]
      assert child["traceId"] == parent["traceId"]
    end
  end

  describe "initial opts" do
    test "4: initial attributes via opts are persisted on the span", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      name = "scenario-4-#{e2e_id}"

      Otel.API.Trace.with_span(
        tracer,
        name,
        [
          attributes: %{
            "e2e.id" => e2e_id,
            "http.method" => "GET",
            "http.status_code" => 200
          }
        ],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert Tempo.attribute(span, "http.method") == "GET"
      assert Tempo.attribute(span, "http.status_code") == 200
    end

    test "5: initial links via opts are persisted on the span", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      linked_name = "linked-5-#{e2e_id}"
      main_name = "scenario-5-#{e2e_id}"

      linked_ctx =
        Otel.API.Trace.start_span(tracer, linked_name, attributes: %{"e2e.id" => e2e_id})

      Otel.API.Trace.Span.end_span(linked_ctx)

      link = %Otel.API.Trace.Link{
        context: linked_ctx,
        attributes: %{"link.kind" => "follows-from"}
      }

      Otel.API.Trace.with_span(
        tracer,
        main_name,
        [links: [link], attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      span = trace_spans(e2e_id) |> Enum.find(&(&1["name"] == main_name))
      assert span
      assert [%{"traceId" => linked_trace_id, "spanId" => linked_span_id}] = span["links"]
      assert linked_trace_id == otlp_id(linked_ctx.trace_id, 128)
      assert linked_span_id == otlp_id(linked_ctx.span_id, 64)
    end

    test "6: is_root: true creates a new root span ignoring the active parent",
         %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      outer_name = "outer-6-#{e2e_id}"
      inner_name = "inner-root-6-#{e2e_id}"

      Otel.API.Trace.with_span(
        tracer,
        outer_name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.API.Trace.with_span(
            tracer,
            inner_name,
            [is_root: true, attributes: %{"e2e.id" => e2e_id}],
            fn _ -> :ok end
          )
        end
      )

      flush()

      spans = trace_spans(e2e_id)
      outer = Enum.find(spans, &(&1["name"] == outer_name))
      inner = Enum.find(spans, &(&1["name"] == inner_name))

      assert outer && inner

      # is_root MUST detach the inner span from the outer, so it
      # has no parentSpanId and lives on a different traceId.
      assert blank_parent?(inner)
      assert inner["traceId"] != outer["traceId"]
    end
  end

  describe "nesting" do
    test "20: with_span inside with_span links child to parent", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      parent_name = "parent-20-#{e2e_id}"
      child_name = "child-20-#{e2e_id}"

      Otel.API.Trace.with_span(
        tracer,
        parent_name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.API.Trace.with_span(
            tracer,
            child_name,
            [attributes: %{"e2e.id" => e2e_id}],
            fn _ -> :ok end
          )
        end
      )

      flush()

      spans = trace_spans(e2e_id)
      parent = Enum.find(spans, &(&1["name"] == parent_name))
      child = Enum.find(spans, &(&1["name"] == child_name))
      assert parent && child
      assert child["traceId"] == parent["traceId"]
      assert child["parentSpanId"] == parent["spanId"]
    end

    test "21: two siblings under one parent share parentSpanId", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      parent_name = "parent-21-#{e2e_id}"
      sib_a = "sib-a-21-#{e2e_id}"
      sib_b = "sib-b-21-#{e2e_id}"

      Otel.API.Trace.with_span(tracer, parent_name, [attributes: %{"e2e.id" => e2e_id}], fn _ ->
        Otel.API.Trace.with_span(tracer, sib_a, [attributes: %{"e2e.id" => e2e_id}], fn _ ->
          :ok
        end)

        Otel.API.Trace.with_span(tracer, sib_b, [attributes: %{"e2e.id" => e2e_id}], fn _ ->
          :ok
        end)
      end)

      flush()

      spans = trace_spans(e2e_id)
      parent = Enum.find(spans, &(&1["name"] == parent_name))
      a = Enum.find(spans, &(&1["name"] == sib_a))
      b = Enum.find(spans, &(&1["name"] == sib_b))
      assert parent && a && b
      assert a["parentSpanId"] == parent["spanId"]
      assert b["parentSpanId"] == parent["spanId"]
    end

    test "22: deep nesting (5 levels) preserves the full parent chain", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())

      nest = fn nest, depth ->
        Otel.API.Trace.with_span(
          tracer,
          "level-#{depth}-22-#{e2e_id}",
          [attributes: %{"e2e.id" => e2e_id}],
          fn _ ->
            if depth < 5, do: nest.(nest, depth + 1), else: :ok
          end
        )
      end

      nest.(nest, 1)

      flush()

      spans = trace_spans(e2e_id)
      by_name = Map.new(spans, &{&1["name"], &1})

      for d <- 2..5 do
        child = by_name["level-#{d}-22-#{e2e_id}"]
        parent = by_name["level-#{d - 1}-22-#{e2e_id}"]
        assert child && parent, "missing level pair #{d - 1}/#{d}"
        assert child["parentSpanId"] == parent["spanId"]
      end
    end

    test "23: child span carries parent's tracestate to Tempo", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())

      ts =
        Otel.API.Trace.TraceState.new()
        |> Otel.API.Trace.TraceState.add("vendor", "abc-#{e2e_id}")

      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<span_id::64>> = :crypto.strong_rand_bytes(8)

      remote_parent = %Otel.API.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        # 0x01 = sampled
        trace_flags: 1,
        tracestate: ts,
        is_remote: true
      }

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), remote_parent)

      Otel.API.Trace.with_span(
        ctx,
        tracer,
        "child-23-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["traceState"] =~ "vendor=abc-#{e2e_id}"
    end
  end

  # ---- helpers ----

  # `/api/search` returns ids in lower hex; `/api/traces/{id}`
  # returns the full OTLP-shaped JSON whose `traceId`/`spanId`/
  # `parentSpanId` are base64 (the protobuf JSON convention for
  # `bytes` fields). Tests that cross-reference the SDK
  # `SpanContext` (which stores ids as plain integers) against
  # those persisted records need `otlp_id/2`.
  @spec trace_spans(e2e_id :: String.t()) :: [map()]
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

  @spec otlp_id(integer :: non_neg_integer(), bits :: pos_integer()) :: String.t()
  defp otlp_id(integer, bits), do: Base.encode64(<<integer::size(bits)>>)

  # `parentSpanId` for a root span comes back as `nil`, `""`, or
  # an all-zero byte field (base64 `"AAAAAAAAAAA="`).
  @spec blank_parent?(span :: map()) :: boolean()
  defp blank_parent?(span) do
    case span["parentSpanId"] do
      nil -> true
      "" -> true
      str -> str =~ ~r/^A+={0,2}$/
    end
  end
end
