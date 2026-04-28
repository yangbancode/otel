defmodule Otel.E2E.SmokeTest do
  use Otel.E2E.Case, async: false

  setup_all do
    Otel.E2E.Emitter.setup_service_name("e2e")
    :ok
  end

  test "trace lands in Tempo", %{marker: marker} do
    emit_span("e2e-smoke", marker)

    assert {:ok, body} = Tempo.find(marker)
    assert body =~ marker
  end

  test "log lands in Loki", %{marker: marker} do
    emit_log("e2e smoke log", marker)

    assert {:ok, body} = Loki.find(marker)
    assert body =~ marker
  end

  test "counter lands in Mimir", %{marker: marker} do
    emit_counter("e2e.smoke", marker)

    assert {:ok, body} = Mimir.find_metric("e2e_smoke_total", marker)
    assert body =~ marker
  end
end
