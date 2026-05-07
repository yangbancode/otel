defmodule Otel.E2E.DecoratorTest do
  @moduledoc """
  E2E coverage for the `@span` decorator
  (`Otel.TelemetrySpanDecorator`) against Tempo.

  Verifies the full `@span [event]` → `:telemetry.span/3` →
  `Otel.TelemetryTracer` → OTLP → Tempo path:

  - Scenario 1 (default): `code.*` semantic-convention attrs
    are auto-injected on every decorated function.
  - Scenario 2 (`capture_io: true`): `__args__` and
    `__result__` land in span metadata as nested kvlistValue
    attributes.

  Tracking matrix: `.claude/docs/e2e.md` §Trace —
  `@span` decorator.
  """

  use Otel.E2E.Case, async: false

  defmodule Default do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_e2e, :default]
    def process(amount, currency, e2e_id) do
      # Set the e2e_id as a top-level span attribute so the
      # standard `Tempo.search/1` helper (keyed on `e2e.id`)
      # can find this trace. The default-mode decorator does
      # NOT auto-capture args, so we set it explicitly.
      Otel.Trace.Span.set_attribute(Otel.Trace.current_span(), "e2e.id", e2e_id)
      "#{amount} #{currency}"
    end
  end

  defmodule Captured do
    use Otel.TelemetrySpanDecorator

    @span event: [:otel_dec_e2e, :captured], capture_io: true
    def process(amount, currency, e2e_id) do
      Otel.Trace.Span.set_attribute(Otel.Trace.current_span(), "e2e.id", e2e_id)
      "#{amount} #{currency} #{e2e_id}"
    end
  end

  describe "@span decorator → OTel Trace → Tempo" do
    test "1: default mode — code.* attrs land in Tempo",
         %{e2e_id: e2e_id} do
      start_tracer!([[:otel_dec_e2e, :default]])

      Default.process(42, "USD", e2e_id)
      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == "otel_dec_e2e.default"

      assert Tempo.attribute(span, "code.function.name") ==
               "Otel.E2E.DecoratorTest.Default.process"

      assert is_binary(Tempo.attribute(span, "code.file.path"))

      assert String.ends_with?(
               Tempo.attribute(span, "code.file.path"),
               "telemetry_span_decorator_test.exs"
             )

      assert is_integer(Tempo.attribute(span, "code.line.number"))
      assert span["status"]["code"] == "STATUS_CODE_OK"

      # Default mode does NOT capture args / result.
      assert Tempo.attribute(span, "__args__") == nil
      assert Tempo.attribute(span, "__result__") == nil
    end

    test "2: capture_io: true — __args__ + __result__ land in Tempo",
         %{e2e_id: e2e_id} do
      start_tracer!([[:otel_dec_e2e, :captured]])

      Captured.process(42, "USD", e2e_id)
      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == "otel_dec_e2e.captured"

      # `code.*` always present.
      assert Tempo.attribute(span, "code.function.name") ==
               "Otel.E2E.DecoratorTest.Captured.process"

      # `__args__` is a nested kvlistValue with the source-text
      # arg names as keys; pulling it back as a map verifies
      # the structure round-tripped through OTLP.
      assert %{
               "amount" => 42,
               "currency" => "USD",
               "e2e_id" => ^e2e_id
             } = Tempo.attribute(span, "__args__")

      # `__result__` is the function's return value.
      assert Tempo.attribute(span, "__result__") == "42 USD #{e2e_id}"
      assert span["status"]["code"] == "STATUS_CODE_OK"
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
end
