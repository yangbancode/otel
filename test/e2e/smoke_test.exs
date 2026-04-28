defmodule Otel.E2E.SmokeTest do
  use Otel.E2E.Case, async: false

  test "trace lands in Tempo", %{e2e_id: e2e_id} do
    tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())

    Otel.API.Trace.with_span(
      tracer,
      "e2e-smoke",
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush()

    assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
  end

  test "log lands in Loki", %{e2e_id: e2e_id} do
    logger = Otel.API.Logs.LoggerProvider.get_logger(scope())

    Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
      body: "e2e smoke log #{e2e_id}",
      severity_number: 9,
      severity_text: "info",
      attributes: %{"e2e.id" => e2e_id}
    })

    flush()

    assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
  end

  test "counter lands in Mimir", %{e2e_id: e2e_id} do
    meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
    counter = Otel.API.Metrics.Meter.create_counter(meter, "e2e.smoke")

    Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

    flush()

    assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_smoke_total"))
  end
end
