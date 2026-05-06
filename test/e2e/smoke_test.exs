defmodule Otel.E2E.SmokeTest do
  use Otel.E2E.Case, async: false

  test "trace lands in Tempo", %{e2e_id: e2e_id} do
    Otel.Trace.with_span(
      "e2e-smoke",
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush()

    assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
  end

  test "log lands in Loki", %{e2e_id: e2e_id} do
    Otel.Logs.emit(
      Otel.Logs.LogRecord.new(%{
        body: "e2e smoke log #{e2e_id}",
        severity_number: 9,
        severity_text: "info",
        attributes: %{"e2e.id" => e2e_id}
      })
    )

    flush()

    assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
  end

  test "counter lands in Mimir", %{e2e_id: e2e_id} do
    counter = Otel.Metrics.Meter.create_counter("e2e.smoke")

    Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

    flush()

    assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_smoke_total"))
  end
end
