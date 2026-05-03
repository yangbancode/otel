defmodule Otel.E2E.SmokeTest do
  use Otel.E2E.Case, async: false

  test "trace lands in Tempo", %{e2e_id: e2e_id} do
    tracer = Otel.Trace.TracerProvider.get_tracer()

    Otel.Trace.with_span(
      tracer,
      "e2e-smoke",
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush()

    assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
  end

  test "log lands in Loki", %{e2e_id: e2e_id} do
    logger = Otel.Logs.LoggerProvider.get_logger()

    Otel.Logs.Logger.emit(logger, %Otel.Logs.LogRecord{
      body: "e2e smoke log #{e2e_id}",
      severity_number: 9,
      severity_text: "info",
      attributes: %{"e2e.id" => e2e_id}
    })

    flush()

    assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
  end

  test "counter lands in Mimir", %{e2e_id: e2e_id} do
    meter = Otel.Metrics.MeterProvider.get_meter()
    counter = Otel.Metrics.Meter.create_counter(meter, "e2e.smoke")

    Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

    flush()

    assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_smoke_total"))
  end
end
