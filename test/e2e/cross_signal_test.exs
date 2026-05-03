defmodule Otel.E2E.CrossSignalTest do
  @moduledoc """
  E2E coverage for cross-signal correlation. Each scenario
  emits on more than one pillar and asserts the persisted
  records actually carry matching cross-signal identifiers
  (trace_id, scope, resource attributes) — not just that they
  landed.

  Tracking matrix: `docs/e2e.md` §Cross-signal / Resource,
  scenarios 1–4.

  ## Detection strategy

  Each backend exposes records through a different envelope
  and applies its own attribute-promotion rules. Hard-coding
  the exact label key is brittle when the LGTM image's
  promotion config changes between minor versions, so the
  assertions JSON-encode each backend's poll result and
  substring-search the rendered text — the same identifier
  just has to appear *somewhere* in the rendered envelope.

  ## Mimir scope-name caveat

  Mimir / Prometheus does not (in LGTM 0.26.0's default OTLP
  receiver config) promote the OTLP `instrumentation_scope_name`
  to a PromQL label, so scenario 4's scope-name check is
  exercised through Tempo + Loki only. Trace and Log carry
  the scope and they correlate with the same `e2e.id` Mimir
  filters on, so the cross-pillar contract is still verified
  end-to-end — just not through Mimir's series labels.
  """

  use Otel.E2E.Case, async: false

  describe "cross-signal correlation" do
    test "1: log emitted inside with_span carries the same trace_id to Loki",
         %{e2e_id: e2e_id} do
      Otel.Trace.with_span(
        "scenario-1-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.Logs.emit(%Otel.Logs.LogRecord{
            body: "scenario-1-log-#{e2e_id}",
            severity_number: 9,
            attributes: %{"e2e.id" => e2e_id}
          })
        end
      )

      flush()

      assert {:ok, [%{"traceID" => trace_id_hex} | _]} = poll(Tempo.search(e2e_id))
      assert {:ok, loki_results} = poll(Loki.query(e2e_id))

      assert text_contains_id?(Jason.encode!(loki_results), trace_id_hex),
             "Loki record didn't carry the span's trace_id (#{trace_id_hex})"
    end

    test "2: counter add inside with_span carries the trace_id to Mimir",
         %{e2e_id: e2e_id} do
      meter = Otel.Metrics.MeterProvider.get_meter()
      metric = "e2e_cross_signal_2_#{e2e_id}"
      counter = Otel.Metrics.Meter.create_counter(meter, metric)

      Otel.Trace.with_span(
        "scenario-2-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
        end
      )

      flush()

      assert {:ok, [%{"traceID" => trace_id_hex} | _]} = poll(Tempo.search(e2e_id))

      assert {:ok, mimir_results} = poll(Mimir.query(e2e_id, "#{metric}_total"))
      {:ok, exemplar_body} = HTTP.get(Mimir.query_exemplars(e2e_id, "#{metric}_total"))

      # The exemplar attached to the metric MUST carry the
      # active span's trace_id. Inline exemplars on the regular
      # `/api/v1/query` envelope are not guaranteed across LGTM
      # versions, so accept either: trace_id in the inline
      # series response OR in the dedicated `/api/v1/query_exemplars`
      # body.
      assert text_contains_id?(Jason.encode!(mimir_results), trace_id_hex) or
               text_contains_id?(exemplar_body, trace_id_hex),
             "Mimir didn't carry the span's trace_id (#{trace_id_hex})"
    end

    test "3: service.name is consistent across all 3 pillars", %{e2e_id: e2e_id} do
      meter = Otel.Metrics.MeterProvider.get_meter()
      metric = "e2e_cross_signal_3_#{e2e_id}"

      Otel.Trace.with_span(
        "scenario-3-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      Otel.Logs.emit(%Otel.Logs.LogRecord{
        body: "scenario-3-log-#{e2e_id}",
        severity_number: 9,
        attributes: %{"e2e.id" => e2e_id}
      })

      counter = Otel.Metrics.Meter.create_counter(meter, metric)
      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      # SDK default Resource sets service.name="unknown_service"
      # when no `:resource` Mix Config is provided. Each backend
      # MUST surface that same value so a single Grafana
      # `service.name="unknown_service"` query unifies all three
      # signals.
      service_name = "unknown_service"

      assert {:ok, [%{"traceID" => trace_id_hex}]} = poll(Tempo.search(e2e_id))
      {:ok, tempo_body} = HTTP.get(Tempo.get_trace(trace_id_hex))
      assert tempo_body =~ service_name, "Tempo missing #{service_name}"

      assert {:ok, loki_results} = poll(Loki.query(e2e_id))

      assert text_contains_id?(Jason.encode!(loki_results), service_name),
             "Loki missing #{service_name}"

      assert {:ok, mimir_results} = poll(Mimir.query(e2e_id, "#{metric}_total"))

      assert text_contains_id?(Jason.encode!(mimir_results), service_name),
             "Mimir missing #{service_name}"
    end

    test "4: InstrumentationScope name is consistent across Trace + Log",
         %{e2e_id: e2e_id} do
      # Minikube hardcodes the InstrumentationScope to the SDK
      # identity (`Otel.InstrumentationScope` defaults), so every
      # signal carries scope name "otel". This test verifies the
      # hardcoded value lands in Tempo + Loki envelopes; Mimir
      # is checked for landing only — see moduledoc § Mimir
      # scope-name caveat.
      scope_name = "otel"
      meter = Otel.Metrics.MeterProvider.get_meter()
      metric = "e2e_cross_signal_4_#{e2e_id}"

      Otel.Trace.with_span(
        "scenario-4-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      Otel.Logs.emit(%Otel.Logs.LogRecord{
        body: "scenario-4-log-#{e2e_id}",
        severity_number: 9,
        attributes: %{"e2e.id" => e2e_id}
      })

      counter = Otel.Metrics.Meter.create_counter(meter, metric)
      Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, [%{"traceID" => trace_id_hex}]} = poll(Tempo.search(e2e_id))
      {:ok, trace_body} = HTTP.get(Tempo.get_trace(trace_id_hex))
      assert trace_body =~ scope_name, "Tempo scope name missing"

      assert {:ok, loki_results} = poll(Loki.query(e2e_id))

      assert text_contains_id?(Jason.encode!(loki_results), scope_name),
             "Loki scope name missing"

      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "#{metric}_total"))
    end
  end

  # ---- helpers ----

  # Substring search that accepts both the original casing and
  # the upper-case variant — Loki / Mimir promote OTLP
  # attributes through their label sanitizers, which sometimes
  # upper-case hex digits A–F.
  @spec text_contains_id?(text :: String.t(), id :: String.t()) :: boolean()
  defp text_contains_id?(text, id) do
    text =~ id or text =~ String.upcase(id)
  end
end
