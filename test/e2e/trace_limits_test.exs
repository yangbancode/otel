defmodule Otel.E2E.TraceLimitsTest do
  @moduledoc """
  E2E coverage for `Otel.Trace.SpanLimits` against Tempo.

  All scenarios share a single SDK restart with deliberately
  small limits so emit-time enforcement (drop counters,
  truncation) is visible to the backend.

  Tracking matrix: `docs/e2e.md` §Trace, scenarios 24–29.
  """

  use Otel.E2E.Case, async: false

  @small_limits %{
    attribute_count_limit: 2,
    attribute_value_length_limit: 8,
    event_count_limit: 2,
    link_count_limit: 2,
    attribute_per_event_limit: 1,
    attribute_per_link_limit: 1
  }

  setup_all do
    prev = Application.get_env(:otel, :trace, [])
    Application.stop(:otel)
    Application.put_env(:otel, :trace, span_limits: @small_limits)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.put_env(:otel, :trace, prev)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  describe "span limits" do
    test "24: attribute_count_limit (2) drops excess attributes", %{e2e_id: e2e_id} do
      emit_with_attrs("scenario-24-#{e2e_id}", e2e_id, %{
        "k1" => "v1",
        "k2" => "v2",
        "k3" => "v3",
        "k4" => "v4"
      })

      assert [span] = trace_spans(e2e_id)
      assert (span["droppedAttributesCount"] || 0) > 0
    end

    test "25: attribute_value_length_limit (8) truncates long string values",
         %{e2e_id: e2e_id} do
      emit_with_attrs("scenario-25-#{e2e_id}", e2e_id, %{"long" => "0123456789ABCDEF"})

      assert [span] = trace_spans(e2e_id)
      assert String.length(Tempo.attribute(span, "long")) == 8
    end

    test "26: event_count_limit (2) drops excess events", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())

      Otel.Trace.with_span(
        tracer,
        "scenario-26-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          for n <- 1..5 do
            Otel.Trace.Span.add_event(span_ctx, Otel.Trace.Event.new("evt-#{n}"))
          end
        end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert (span["droppedEventsCount"] || 0) > 0
    end

    test "27: link_count_limit (2) drops excess links", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())

      links =
        for n <- 1..5 do
          ctx =
            Otel.Trace.start_span(tracer, "target-27-#{n}-#{e2e_id}",
              attributes: %{"e2e.id" => e2e_id}
            )

          Otel.Trace.Span.end_span(ctx)
          %Otel.Trace.Link{context: ctx}
        end

      Otel.Trace.with_span(
        tracer,
        "scenario-27-#{e2e_id}",
        [links: links, attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      span = trace_spans(e2e_id) |> Enum.find(&(&1["name"] == "scenario-27-#{e2e_id}"))
      assert (span["droppedLinksCount"] || 0) > 0
    end

    test "28: attribute_per_event_limit (1) drops excess event attrs", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())

      Otel.Trace.with_span(
        tracer,
        "scenario-28-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          event =
            Otel.Trace.Event.new("over", %{"a" => "1", "b" => "2", "c" => "3"})

          Otel.Trace.Span.add_event(span_ctx, event)
        end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert [event] = span["events"]
      assert (event["droppedAttributesCount"] || 0) > 0
    end

    test "29: attribute_per_link_limit (1) drops excess link attrs", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())

      target =
        Otel.Trace.start_span(tracer, "target-29-#{e2e_id}", attributes: %{"e2e.id" => e2e_id})

      Otel.Trace.Span.end_span(target)

      link = %Otel.Trace.Link{
        context: target,
        attributes: %{"a" => "1", "b" => "2", "c" => "3"}
      }

      Otel.Trace.with_span(
        tracer,
        "scenario-29-#{e2e_id}",
        [links: [link], attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      span = trace_spans(e2e_id) |> Enum.find(&(&1["name"] == "scenario-29-#{e2e_id}"))
      assert [link] = span["links"]
      assert (link["droppedAttributesCount"] || 0) > 0
    end
  end

  # ---- helpers ----

  defp emit_with_attrs(name, e2e_id, attrs) do
    tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())

    Otel.Trace.with_span(
      tracer,
      name,
      [attributes: Map.put(attrs, "e2e.id", e2e_id)],
      fn _ -> :ok end
    )

    flush()
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
end
