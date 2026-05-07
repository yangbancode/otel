defmodule Otel.E2E.SmokeTest do
  @moduledoc """
  Quick smoke checks for each pillar's wire-format
  integrity — one minimal scenario per backend with **value**
  assertion (not just landing). If any of these fail, the
  whole e2e suite is suspect.

  Tracking matrix: `.claude/docs/e2e.md` §Smoke, scenarios 1–3.
  """
  use Otel.E2E.Case, async: false

  test "trace lands in Tempo with the configured name", %{e2e_id: e2e_id} do
    name = "e2e-smoke-#{e2e_id}"

    Otel.Trace.with_span(name, [attributes: %{"e2e.id" => e2e_id}], fn _ -> :ok end)
    flush()

    assert {:ok, [%{"traceID" => trace_id_hex} | _]} = poll(Tempo.search(e2e_id))
    {:ok, body} = HTTP.get(Tempo.get_trace(trace_id_hex))
    {:ok, %{"batches" => batches}} = Jason.decode(body)

    span_names =
      batches
      |> Enum.flat_map(&(&1["scopeSpans"] || []))
      |> Enum.flat_map(&(&1["spans"] || []))
      |> Enum.map(& &1["name"])

    assert name in span_names
  end

  test "log lands in Loki with the rendered body", %{e2e_id: e2e_id} do
    body = "e2e smoke log #{e2e_id}"

    Otel.Logs.emit(
      Otel.Logs.LogRecord.new(%{
        body: body,
        severity_number: 9,
        severity_text: "info",
        attributes: %{"e2e.id" => e2e_id}
      })
    )

    flush()

    assert {:ok, results} = poll(Loki.query(body))
    assert body in Loki.lines(results)
  end

  test "counter lands in Mimir with the right value", %{e2e_id: e2e_id} do
    counter = Otel.Metrics.Meter.create_counter("e2e.smoke.#{e2e_id}")

    Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
    Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
    flush()

    metric = "e2e_smoke_#{e2e_id}_total"
    assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, metric))
    # Two adds → cumulative value of 2.
    assert Mimir.value(result) == 2.0
  end
end
