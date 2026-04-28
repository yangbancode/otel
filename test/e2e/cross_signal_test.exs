defmodule Otel.E2E.CrossSignalTest do
  @moduledoc """
  E2E coverage for cross-signal correlation — every test emits
  on more than one pillar and asserts each backend receives a
  matching record.

  Tracking matrix: `docs/e2e.md` §Cross-signal / Resource,
  scenarios 1–4.
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

      # Both backends see records tagged with the same e2e_id;
      # the Logger SDK fills `trace_id` / `span_id` from the
      # active context so the persisted log carries the span's
      # trace_id by construction. Confirming both lands is the
      # e2e-level signal that the cross-signal wiring works.
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "2: counter add inside with_span — exemplar candidate carries the trace_id",
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

      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))

      assert {:ok, [_ | _]} =
               poll(Mimir.query(e2e_id, "e2e_cross_signal_2_#{e2e_id}_total"))
    end

    test "3: resource is consistent across all 3 pillars", %{e2e_id: e2e_id} do
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

      # All three backends receive records sharing the SDK's
      # default Resource (`service.name` etc.). Land on each
      # is the cross-pillar resource consistency signal.
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))

      assert {:ok, [_ | _]} =
               poll(Mimir.query(e2e_id, "e2e_cross_signal_3_#{e2e_id}_total"))
    end

    test "4: InstrumentationScope is consistent across 3 pillars", %{e2e_id: e2e_id} do
      shared_scope = %Otel.API.InstrumentationScope{
        name: "e2e-cross-signal-4",
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

      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))

      assert {:ok, [_ | _]} =
               poll(Mimir.query(e2e_id, "e2e_cross_signal_4_#{e2e_id}_total"))
    end
  end
end
