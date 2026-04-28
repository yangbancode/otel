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
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      logger = Otel.API.Logs.LoggerProvider.get_logger(scope())

      Otel.API.Trace.with_span(
        tracer,
        "scenario-1-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
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
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      metric = "e2e_cross_signal_2_#{e2e_id}"
      counter = Otel.API.Metrics.Meter.create_counter(meter, metric)

      Otel.API.Trace.with_span(
        tracer,
        "scenario-2-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
        end
      )

      flush()

      assert {:ok, [%{"traceID" => trace_id_hex} | _]} = poll(Tempo.search(e2e_id))

      assert {:ok, mimir_results} = poll(Mimir.query(e2e_id, "#{metric}_total"))

      # The exemplar attached to the metric MUST carry the
      # active span's trace_id. Inline exemplars on the regular
      # `/api/v1/query` envelope are not guaranteed across LGTM
      # versions, so we accept either form: trace_id appears in
      # the inline series response OR in the dedicated
      # `/api/v1/query_exemplars` body.
      mimir_payload = Jason.encode!(mimir_results)

      ok =
        text_contains_id?(mimir_payload, trace_id_hex) or
          exemplar_carries?(e2e_id, "#{metric}_total", trace_id_hex)

      assert ok, "Mimir didn't carry the span's trace_id (#{trace_id_hex})"
    end

    test "3: service.name is consistent across all 3 pillars", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      logger = Otel.API.Logs.LoggerProvider.get_logger(scope())
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      metric = "e2e_cross_signal_3_#{e2e_id}"

      Otel.API.Trace.with_span(
        tracer,
        "scenario-3-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
        body: "scenario-3-log-#{e2e_id}",
        severity_number: 9,
        attributes: %{"e2e.id" => e2e_id}
      })

      counter = Otel.API.Metrics.Meter.create_counter(meter, metric)
      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      # SDK default Resource sets service.name="unknown_service"
      # when no OTEL_SERVICE_NAME is provided. Each backend MUST
      # surface that same value so a single Grafana
      # `service.name="unknown_service"` query unifies all three
      # signals.
      service_name = "unknown_service"

      assert backend_carries?(e2e_id, service_name, metric: metric),
             "service.name=#{service_name} missing from one of the backends"
    end

    test "4: InstrumentationScope name is consistent across Trace + Log",
         %{e2e_id: e2e_id} do
      scope_name = "e2e-cross-signal-4-#{e2e_id}"

      shared_scope = %Otel.API.InstrumentationScope{
        name: scope_name,
        version: "0.1.0"
      }

      tracer = Otel.API.Trace.TracerProvider.get_tracer(shared_scope)
      logger = Otel.API.Logs.LoggerProvider.get_logger(shared_scope)
      meter = Otel.API.Metrics.MeterProvider.get_meter(shared_scope)
      metric = "e2e_cross_signal_4_#{e2e_id}"

      Otel.API.Trace.with_span(
        tracer,
        "scenario-4-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
        body: "scenario-4-log-#{e2e_id}",
        severity_number: 9,
        attributes: %{"e2e.id" => e2e_id}
      })

      counter = Otel.API.Metrics.Meter.create_counter(meter, metric)
      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      # Tempo + Loki carry scope_name in their envelopes. Mimir
      # is checked for landing only — see moduledoc § Mimir
      # scope-name caveat.
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

  # Common search across all three backend envelopes for a
  # value that should appear identically on every pillar
  # (used by scenario 3 for `service.name`).
  @spec backend_carries?(
          e2e_id :: String.t(),
          value :: String.t(),
          opts :: [metric: String.t()]
        ) :: boolean()
  defp backend_carries?(e2e_id, value, opts) do
    metric = Keyword.fetch!(opts, :metric)

    {:ok, [%{"traceID" => trace_id_hex}]} = poll(Tempo.search(e2e_id))
    {:ok, tempo_body} = HTTP.get(Tempo.get_trace(trace_id_hex))
    {:ok, loki_results} = poll(Loki.query(e2e_id))
    {:ok, mimir_results} = poll(Mimir.query(e2e_id, "#{metric}_total"))

    tempo_body =~ value and
      text_contains_id?(Jason.encode!(loki_results), value) and
      text_contains_id?(Jason.encode!(mimir_results), value)
  end

  # `/api/v1/query_exemplars` lookup, used as a fallback when
  # exemplars don't ride along with the inline series response.
  @spec exemplar_carries?(
          e2e_id :: String.t(),
          metric :: String.t(),
          trace_id_hex :: String.t()
        ) :: boolean()
  defp exemplar_carries?(e2e_id, metric, trace_id_hex) do
    case HTTP.get(Mimir.query_exemplars(e2e_id, metric)) do
      {:ok, body} -> text_contains_id?(body, trace_id_hex)
      _ -> false
    end
  end
end
