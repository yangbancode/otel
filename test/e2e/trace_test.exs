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
      assert linked_trace_id == linked_ctx.trace_id |> integer_hex(32)
      assert linked_span_id == linked_ctx.span_id |> integer_hex(16)
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

  # ---- helpers ----

  @spec trace_spans(e2e_id :: String.t()) :: [map()]
  defp trace_spans(e2e_id) do
    {:ok, traces} = poll(Tempo.query(e2e_id))

    Enum.flat_map(traces, fn %{"traceID" => trace_id} ->
      {:ok, trace} = fetch_json(Tempo.trace(trace_id))
      Tempo.spans_of(trace)
    end)
  end

  # OTLP/JSON encodes ids as lowercase hex with no separators.
  # The SDK SpanContext stores them as plain integers, so tests
  # that cross-reference the carrier and the persisted record
  # need this conversion.
  @spec integer_hex(integer :: non_neg_integer(), bits :: pos_integer()) :: String.t()
  defp integer_hex(integer, bits) do
    integer
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(div(bits, 4), "0")
  end

  # Tempo renders a missing parentSpanId either as `nil` or as a
  # zero-filled hex string depending on encoder version; treat
  # both as "no parent".
  @spec blank_parent?(span :: map()) :: boolean()
  defp blank_parent?(span) do
    case span["parentSpanId"] do
      nil -> true
      "" -> true
      hex -> String.match?(hex, ~r/^0+$/)
    end
  end
end
