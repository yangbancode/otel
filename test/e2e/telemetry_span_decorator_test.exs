defmodule Otel.E2E.DecoratorTest do
  @moduledoc """
  E2E coverage for the `@span` decorator
  (`Otel.TelemetrySpanDecorator`) against Tempo.

  Verifies the full `@span [event]` → `:telemetry.span/3` →
  `Otel.TelemetryTracer` → OTLP → Tempo path: a function
  annotated with `@span` produces a span carrying its
  source-named arguments as attributes.

  Tracking matrix: `.claude/docs/e2e.md` §Trace —
  `@span` decorator.
  """

  use Otel.E2E.Case, async: false

  defmodule Fixture do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_e2e, :process]
    def process(amount, currency, e2e_id) do
      "#{amount} #{currency} #{e2e_id}"
    end
  end

  describe "@span decorator → OTel Trace → Tempo" do
    test "1: decorated function — span name + auto-captured args land in Tempo",
         %{e2e_id: e2e_id} do
      start_tracer!([[:otel_dec_e2e, :process]])

      Fixture.process(42, "USD", e2e_id)
      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == "otel_dec_e2e.process"
      assert Tempo.attribute(span, "amount") == 42
      assert Tempo.attribute(span, "currency") == "USD"
      assert Tempo.attribute(span, "e2e_id") == e2e_id
      assert span["status"]["code"] == "STATUS_CODE_OK"
    end
  end

  # ---- helpers ----

  defp start_tracer!(events) do
    pid = start_supervised!({Otel.TelemetryTracer, events: events})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    pid
  end

  # `@span` captures arg names verbatim — `e2e_id` arg becomes
  # the `e2e_id` (underscore) span attribute, not `e2e.id`
  # (dot). `Tempo.search/1` is hardcoded to the dotted tag, so
  # search by the underscore form here instead.
  defp trace_spans(e2e_id) do
    query = URI.encode_query(tags: "e2e_id=#{e2e_id}", limit: 32)
    url = "http://localhost:3200/api/search?#{query}"
    {:ok, traces} = poll(url)

    Enum.flat_map(traces, fn %{"traceID" => trace_id} ->
      {:ok, body} = HTTP.get(Tempo.get_trace(trace_id))
      {:ok, %{"batches" => batches}} = Jason.decode(body)

      Enum.flat_map(batches, fn b ->
        Enum.flat_map(b["scopeSpans"] || [], &(&1["spans"] || []))
      end)
    end)
  end
end
