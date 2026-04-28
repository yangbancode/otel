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

  Each backend exposes its records through a different envelope
  and applies its own attribute-promotion rules (Loki promotes
  selected OTLP attrs to stream labels; Mimir to PromQL labels;
  Tempo's `/api/traces/{id}` returns OTLP-shaped JSON
  unchanged). Hard-coding "look in `stream["trace_id"]`" is
  brittle when the LGTM image's promotion config changes
  between minor versions. So the assertions JSON-encode each
  backend's poll result and substring-search the rendered
  text. That stays correct whether the value lands on a label,
  in structured metadata, on the line itself, or as an OTLP
  attribute — the *same* identifier just has to appear in the
  rendered envelope.
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

      # Tempo returns lower-hex traceID; Loki receives the OTLP
      # `trace_id` attribute the SDK auto-fills from the active
      # span context. They must reference the same trace_id —
      # case-insensitive because Loki promotion may upper-case.
      assert {:ok, [%{"traceID" => trace_id_hex} | _]} = poll(Tempo.search(e2e_id))
      assert {:ok, loki_results} = poll(Loki.query(e2e_id))

      assert text_contains_id?(Jason.encode!(loki_results), trace_id_hex),
             "Loki record didn't carry the span's trace_id (#{trace_id_hex})"
    end

    test "2: counter add inside with_span carries the trace_id to Mimir",
         %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      counter =
        Otel.API.Metrics.Meter.create_counter(meter, "e2e_cross_signal_2_#{e2e_id}")

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

      assert {:ok, mimir_results} =
               poll(Mimir.query(e2e_id, "e2e_cross_signal_2_#{e2e_id}_total"))

      # The exemplar attached to the metric sample MUST carry
      # the active span's trace_id. The exemplar arrives through
      # one of two channels in LGTM:
      #
      # - inline on the `/api/v1/query` series object, or
      # - via the dedicated `/api/v1/query_exemplars` endpoint.
      #
      # We don't know which the running LGTM build exposes, so
      # the assertion accepts either: trace_id appears somewhere
      # in the inline series response, OR in a follow-up
      # exemplar fetch.
      mimir_payload = Jason.encode!(mimir_results)

      ok =
        text_contains_id?(mimir_payload, trace_id_hex) or
          mimir_exemplar_carries?(e2e_id, "e2e_cross_signal_2_#{e2e_id}_total", trace_id_hex)

      assert ok, "Mimir record didn't carry the span's trace_id (#{trace_id_hex})"
    end

    test "3: service.name is consistent across all 3 pillars", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      logger = Otel.API.Logs.LoggerProvider.get_logger(scope())
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

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

      counter =
        Otel.API.Metrics.Meter.create_counter(meter, "e2e_cross_signal_3_#{e2e_id}")

      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      # The SDK's default Resource sets `service.name=
      # "unknown_service"` when no `OTEL_SERVICE_NAME` is
      # provided (this test runs without it). Each backend
      # MUST surface that same value so a single
      # `service.name="unknown_service"` query in Grafana
      # would unify all three signals.
      service_name = "unknown_service"

      assert {:ok, [%{"traceID" => trace_id_hex}]} = poll(Tempo.search(e2e_id))
      {:ok, trace_body} = HTTP.get(Tempo.get_trace(trace_id_hex))
      assert trace_body =~ service_name, "Tempo resource missing #{service_name}"

      assert {:ok, loki_results} = poll(Loki.query(e2e_id))

      assert text_contains_id?(Jason.encode!(loki_results), service_name),
             "Loki resource missing #{service_name}"

      assert {:ok, mimir_results} =
               poll(Mimir.query(e2e_id, "e2e_cross_signal_3_#{e2e_id}_total"))

      assert text_contains_id?(Jason.encode!(mimir_results), service_name),
             "Mimir resource missing #{service_name}"
    end

    test "4: InstrumentationScope name is consistent across 3 pillars", %{e2e_id: e2e_id} do
      scope_name = "e2e-cross-signal-4-#{e2e_id}"

      shared_scope = %Otel.API.InstrumentationScope{
        name: scope_name,
        version: "0.1.0"
      }

      tracer = Otel.API.Trace.TracerProvider.get_tracer(shared_scope)
      logger = Otel.API.Logs.LoggerProvider.get_logger(shared_scope)
      meter = Otel.API.Metrics.MeterProvider.get_meter(shared_scope)

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

      counter =
        Otel.API.Metrics.Meter.create_counter(meter, "e2e_cross_signal_4_#{e2e_id}")

      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      # `scope_name` includes the e2e_id so it's globally
      # unique to this run — much stronger than asserting on
      # the default scope ("e2e") that every other test also
      # uses.
      assert {:ok, [%{"traceID" => trace_id_hex}]} = poll(Tempo.search(e2e_id))
      {:ok, trace_body} = HTTP.get(Tempo.get_trace(trace_id_hex))
      assert trace_body =~ scope_name, "Tempo scope name missing"

      assert {:ok, loki_results} = poll(Loki.query(e2e_id))

      assert text_contains_id?(Jason.encode!(loki_results), scope_name),
             "Loki scope name missing"

      assert {:ok, mimir_results} =
               poll(Mimir.query(e2e_id, "e2e_cross_signal_4_#{e2e_id}_total"))

      assert text_contains_id?(Jason.encode!(mimir_results), scope_name),
             "Mimir scope name missing"
    end
  end

  # ---- helpers ----

  # Substring search that accepts both the original casing and
  # the upper-case variant — Loki / Mimir promote OTLP
  # `trace_id` attributes through their label sanitizers,
  # which sometimes upper-case hex digits A–F.
  @spec text_contains_id?(text :: String.t(), id :: String.t()) :: boolean()
  defp text_contains_id?(text, id) do
    text =~ id or text =~ String.upcase(id)
  end

  # `/api/v1/query_exemplars` lookup, used as a fallback when
  # exemplars don't ride along with the inline series response.
  @spec mimir_exemplar_carries?(
          e2e_id :: String.t(),
          metric :: String.t(),
          trace_id_hex :: String.t()
        ) :: boolean()
  defp mimir_exemplar_carries?(e2e_id, metric, trace_id_hex) do
    url =
      %URI{
        scheme: "http",
        host: "localhost",
        port: 9090,
        path: "/api/v1/query_exemplars",
        query: URI.encode_query(query: ~s(#{metric}{e2e_id="#{e2e_id}"}))
      }
      |> URI.to_string()

    case HTTP.get(url) do
      {:ok, body} -> text_contains_id?(body, trace_id_hex)
      _ -> false
    end
  end
end
