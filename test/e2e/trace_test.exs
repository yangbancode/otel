defmodule Otel.E2E.TraceTest do
  @moduledoc """
  E2E coverage for `Otel.Trace` against Tempo.

  Each scenario emits a span (or spans) tagged with the test's
  unique `e2e.id`, force-flushes, locates the trace(s) by tag,
  fetches the full OTLP-shaped JSON, and asserts on the relevant
  detail.

  Tracking matrix: `docs/e2e.md` §Trace.
  """

  use Otel.E2E.Case, async: false

  describe "lifecycle" do
    test "1: single span via with_span lands with the configured name", %{e2e_id: e2e_id} do
      name = "scenario-1-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == name
    end

    test "2: manual start_span + end_span lands the same span", %{e2e_id: e2e_id} do
      name = "scenario-2-#{e2e_id}"

      span_ctx =
        Otel.Trace.start_span(name, attributes: %{"e2e.id" => e2e_id})

      Otel.Trace.Span.end_span(span_ctx)

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == name
    end

    test "3: start_span/4 with explicit parent context links the child to that parent",
         %{e2e_id: e2e_id} do
      parent_name = "parent-3-#{e2e_id}"
      child_name = "child-3-#{e2e_id}"

      parent_ctx =
        Otel.Trace.start_span(parent_name, attributes: %{"e2e.id" => e2e_id})

      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), parent_ctx)

      child_ctx =
        Otel.Trace.start_span(ctx, child_name, attributes: %{"e2e.id" => e2e_id})

      Otel.Trace.Span.end_span(child_ctx)
      Otel.Trace.Span.end_span(parent_ctx)

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
      name = "scenario-4-#{e2e_id}"

      Otel.Trace.with_span(
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
      linked_name = "linked-5-#{e2e_id}"
      main_name = "scenario-5-#{e2e_id}"

      linked_ctx =
        Otel.Trace.start_span(linked_name, attributes: %{"e2e.id" => e2e_id})

      Otel.Trace.Span.end_span(linked_ctx)

      link =
        Otel.Trace.Link.new(%{
          context: linked_ctx,
          attributes: %{"link.kind" => "follows-from"}
        })

      Otel.Trace.with_span(
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
      outer_name = "outer-6-#{e2e_id}"
      inner_name = "inner-root-6-#{e2e_id}"

      Otel.Trace.with_span(
        outer_name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.Trace.with_span(
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

  describe "mutations" do
    test "7: set_attribute/3 mid-span persists on the span", %{e2e_id: e2e_id} do
      name = "scenario-7-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Otel.Trace.Span.set_attribute(span_ctx, "added.key", "added-value")
        end
      )

      flush()
      assert [span] = trace_spans(e2e_id)
      assert Tempo.attribute(span, "added.key") == "added-value"
    end

    test "8: set_attributes/2 bulk persists every key", %{e2e_id: e2e_id} do
      name = "scenario-8-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Otel.Trace.Span.set_attributes(span_ctx, %{
            "k.string" => "v",
            "k.int" => 2,
            "k.bool" => true
          })
        end
      )

      flush()
      assert [span] = trace_spans(e2e_id)
      assert Tempo.attribute(span, "k.string") == "v"
      assert Tempo.attribute(span, "k.int") == 2
      assert Tempo.attribute(span, "k.bool") == true
    end

    test "9: add_event/2 single event lands on the span", %{e2e_id: e2e_id} do
      name = "scenario-9-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          event = Otel.Trace.Event.new(%{name: "evt-1", attributes: %{"event.attr" => "x"}})
          Otel.Trace.Span.add_event(span_ctx, event)
        end
      )

      flush()
      assert [span] = trace_spans(e2e_id)
      assert [%{"name" => "evt-1"}] = span["events"]
    end

    test "10: add_event/2 multiple events preserve emission order", %{e2e_id: e2e_id} do
      name = "scenario-10-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          for n <- 1..3 do
            Otel.Trace.Span.add_event(span_ctx, Otel.Trace.Event.new(%{name: "evt-#{n}"}))
          end
        end
      )

      flush()
      assert [span] = trace_spans(e2e_id)
      assert ["evt-1", "evt-2", "evt-3"] = Enum.map(span["events"], & &1["name"])
    end

    test "11: add_link/2 single link mid-span", %{e2e_id: e2e_id} do
      target_ctx =
        Otel.Trace.start_span("target-11-#{e2e_id}", attributes: %{"e2e.id" => e2e_id})

      Otel.Trace.Span.end_span(target_ctx)

      name = "scenario-11-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Otel.Trace.Span.add_link(span_ctx, Otel.Trace.Link.new(%{context: target_ctx}))
        end
      )

      flush()
      span = trace_spans(e2e_id) |> Enum.find(&(&1["name"] == name))
      assert [%{"spanId" => linked_span_id}] = span["links"]
      assert linked_span_id == otlp_id(target_ctx.span_id, 64)
    end

    test "12: add_link/2 multiple links preserve emission order", %{e2e_id: e2e_id} do
      targets =
        for n <- 1..3 do
          ctx =
            Otel.Trace.start_span("target-12-#{n}-#{e2e_id}",
              attributes: %{"e2e.id" => e2e_id}
            )

          Otel.Trace.Span.end_span(ctx)
          ctx
        end

      name = "scenario-12-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          for ctx <- targets do
            Otel.Trace.Span.add_link(span_ctx, Otel.Trace.Link.new(%{context: ctx}))
          end
        end
      )

      flush()
      span = trace_spans(e2e_id) |> Enum.find(&(&1["name"] == name))
      expected = Enum.map(targets, &otlp_id(&1.span_id, 64))
      actual = Enum.map(span["links"], & &1["spanId"])
      assert expected == actual
    end

    test "13: set_status/2 :ok lands on the span", %{e2e_id: e2e_id} do
      name = "scenario-13-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Otel.Trace.Span.set_status(span_ctx, Otel.Trace.Status.new(%{code: :ok}))
        end
      )

      flush()
      assert [span] = trace_spans(e2e_id)
      # OTLP/JSON status code: 1 = OK, 2 = ERROR.
      assert span["status"]["code"] in [1, "STATUS_CODE_OK"]
    end

    test "14: set_status/2 :error carries the description", %{e2e_id: e2e_id} do
      name = "scenario-14-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Otel.Trace.Span.set_status(
            span_ctx,
            Otel.Trace.Status.new(%{code: :error, description: "boom"})
          )
        end
      )

      flush()
      assert [span] = trace_spans(e2e_id)
      assert span["status"]["code"] in [2, "STATUS_CODE_ERROR"]
      assert span["status"]["message"] == "boom"
    end

    test "15: update_name/2 changes the reported name", %{e2e_id: e2e_id} do
      initial = "initial-15-#{e2e_id}"
      final = "final-15-#{e2e_id}"

      Otel.Trace.with_span(
        initial,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Otel.Trace.Span.update_name(span_ctx, final)
        end
      )

      flush()
      assert [span] = trace_spans(e2e_id)
      assert span["name"] == final
    end
  end

  describe "kinds" do
    test "16: each of the 5 SpanKind variants round-trips through Tempo", %{e2e_id: e2e_id} do
      kinds_to_otlp = [
        {:internal, [1, "SPAN_KIND_INTERNAL"]},
        {:server, [2, "SPAN_KIND_SERVER"]},
        {:client, [3, "SPAN_KIND_CLIENT"]},
        {:producer, [4, "SPAN_KIND_PRODUCER"]},
        {:consumer, [5, "SPAN_KIND_CONSUMER"]}
      ]

      for {kind, _} <- kinds_to_otlp do
        Otel.Trace.with_span(
          "scenario-16-#{kind}-#{e2e_id}",
          [kind: kind, attributes: %{"e2e.id" => e2e_id}],
          fn _ -> :ok end
        )
      end

      flush()

      spans = trace_spans(e2e_id)

      for {kind, accepted} <- kinds_to_otlp do
        span = Enum.find(spans, &(&1["name"] == "scenario-16-#{kind}-#{e2e_id}"))
        assert span, "missing span for kind #{kind}"
        assert span["kind"] in accepted, "kind #{kind} got #{inspect(span["kind"])}"
      end
    end
  end

  describe "exception" do
    test "17: with_span auto-records a raised exception + Error status", %{e2e_id: e2e_id} do
      name = "scenario-17-#{e2e_id}"

      assert_raise RuntimeError, "boom-17", fn ->
        Otel.Trace.with_span(
          name,
          [attributes: %{"e2e.id" => e2e_id}],
          fn _ -> raise "boom-17" end
        )
      end

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["status"]["code"] in [2, "STATUS_CODE_ERROR"]
      assert [%{"name" => "exception"} = event] = span["events"]
      assert Tempo.attribute(event, "exception.type") =~ "RuntimeError"
      assert Tempo.attribute(event, "exception.message") == "boom-17"
    end

    test "18: record_exception/3 records a manually-built exception event", %{e2e_id: e2e_id} do
      name = "scenario-18-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          exception = ArgumentError.exception("manual-18")
          Otel.Trace.Span.record_exception(span_ctx, exception, [])
        end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert [%{"name" => "exception"} = event] = span["events"]
      assert Tempo.attribute(event, "exception.type") =~ "ArgumentError"
      assert Tempo.attribute(event, "exception.message") == "manual-18"
    end

    test "19: record_exception/4 caller-supplied attrs override exception.* defaults",
         %{e2e_id: e2e_id} do
      name = "scenario-19-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          exception = ArgumentError.exception("default-msg-19")

          Otel.Trace.Span.record_exception(span_ctx, exception, [], %{
            "exception.message" => "override-19",
            "extra" => "x"
          })
        end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert [%{"name" => "exception"} = event] = span["events"]
      assert Tempo.attribute(event, "exception.message") == "override-19"
      assert Tempo.attribute(event, "extra") == "x"
    end
  end

  describe "nesting" do
    test "20: with_span inside with_span links child to parent", %{e2e_id: e2e_id} do
      parent_name = "parent-20-#{e2e_id}"
      child_name = "child-20-#{e2e_id}"

      Otel.Trace.with_span(
        parent_name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.Trace.with_span(
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
      parent_name = "parent-21-#{e2e_id}"
      sib_a = "sib-a-21-#{e2e_id}"
      sib_b = "sib-b-21-#{e2e_id}"

      Otel.Trace.with_span(parent_name, [attributes: %{"e2e.id" => e2e_id}], fn _ ->
        Otel.Trace.with_span(sib_a, [attributes: %{"e2e.id" => e2e_id}], fn _ ->
          :ok
        end)

        Otel.Trace.with_span(sib_b, [attributes: %{"e2e.id" => e2e_id}], fn _ ->
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
      nest = fn nest, depth ->
        Otel.Trace.with_span(
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
      ts =
        Otel.Trace.TraceState.new()
        |> Otel.Trace.TraceState.add("vendor", "abc-#{e2e_id}")

      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<span_id::64>> = :crypto.strong_rand_bytes(8)

      remote_parent = %Otel.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        # 0x01 = sampled
        trace_flags: 1,
        tracestate: ts,
        is_remote: true
      }

      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), remote_parent)

      Otel.Trace.with_span(
        ctx,
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
