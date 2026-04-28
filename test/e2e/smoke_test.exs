defmodule Otel.E2E.SmokeTest do
  use Otel.E2E.Case, async: false

  setup_all do
    Otel.E2E.Emitter.setup_service_name("e2e")
    :ok
  end

  test "trace lands in Tempo", %{e2e_id: e2e_id} do
    emit_span("e2e-smoke", e2e_id)

    assert {:ok, body} = Tempo.find(e2e_id)
    assert body =~ e2e_id
  end

  test "log lands in Loki", %{e2e_id: e2e_id} do
    emit_log("e2e smoke log", e2e_id)

    assert {:ok, body} = Loki.find(e2e_id)
    assert body =~ e2e_id
  end

  test "counter lands in Mimir", %{e2e_id: e2e_id} do
    emit_counter("e2e.smoke", e2e_id)

    assert {:ok, body} = Mimir.find_metric("e2e_smoke_total", e2e_id)
    assert body =~ e2e_id
  end
end
