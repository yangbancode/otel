defmodule Otel.E2E.SmokeTest do
  use Otel.E2E.Case, async: false

  setup_all do
    Otel.E2E.Emitter.setup_service_name("e2e")
    :ok
  end

  test "trace lands in Tempo", %{e2e_id: e2e_id} do
    tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())

    Otel.API.Trace.with_span(
      tracer,
      "e2e-smoke",
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush_traces()

    assert {:ok, body} = Tempo.find(e2e_id)
    assert body =~ e2e_id
  end

  test "log lands in Loki", %{e2e_id: e2e_id} do
    logger = Otel.API.Logs.LoggerProvider.get_logger(scope())

    Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
      body: "e2e smoke log",
      severity_number: 9,
      severity_text: "info",
      attributes: %{"e2e.id" => e2e_id}
    })

    flush_logs()

    assert {:ok, body} = Loki.find(e2e_id)
    assert body =~ e2e_id
  end

  test "counter lands in Mimir", %{e2e_id: e2e_id} do
    meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
    counter = Otel.API.Metrics.Meter.create_counter(meter, "e2e.smoke")

    Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

    flush_metrics()

    assert {:ok, body} = Mimir.find_metric("e2e_smoke_total", e2e_id)
    assert body =~ e2e_id
  end
end
