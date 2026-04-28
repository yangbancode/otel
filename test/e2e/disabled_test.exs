defmodule Otel.E2E.DisabledTest do
  @moduledoc """
  E2E coverage for global SDK control — both knobs that should
  *prevent* records from reaching the backends.

  Tracking matrix: `docs/e2e.md` §Global SDK control,
  scenarios 1–2.
  """

  use Otel.E2E.Case, async: false

  describe "OTEL_SDK_DISABLED" do
    test "1: OTEL_SDK_DISABLED=true silences all 3 pillars", %{e2e_id: e2e_id} do
      restart_with_env(%{"OTEL_SDK_DISABLED" => "true"})

      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      logger = Otel.API.Logs.LoggerProvider.get_logger(scope())
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      Otel.API.Trace.with_span(
        tracer,
        "scenario-1-trace-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
        body: "scenario-1-log-#{e2e_id}",
        severity_number: 9,
        attributes: %{"e2e.id" => e2e_id}
      })

      counter =
        Otel.API.Metrics.Meter.create_counter(meter, "e2e_disabled_1_#{e2e_id}")

      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

      flush()

      # SDK_DISABLED=true makes every signal a no-op at the API
      # layer, so no traffic ever reaches the backends. There's
      # nothing to wait for — `empty?/1` does a single fetch
      # and asserts the result list is empty, instead of polling
      # for ~30s per backend like the positive scenarios do.
      assert empty?(Tempo.search(e2e_id))
      assert empty?(Loki.query(e2e_id))
      assert empty?(Mimir.query(e2e_id, "e2e_disabled_1_#{e2e_id}_total"))
    end
  end

  describe "Provider shutdown" do
    test "2: post-shutdown emits don't reach the backend", %{e2e_id: e2e_id} do
      # Shut down the trace provider, then attempt to emit. The
      # spec mandates emits after shutdown become no-ops; the
      # post-shutdown span must not appear in Tempo. We do this
      # with the trace pillar only because shutting all three
      # would leave the SDK unable to recover for subsequent
      # tests; `setup_otel_for_test/0` puts the SDK back in
      # working order on `on_exit`.
      restart_for_shutdown_test()

      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      :ok = Otel.SDK.Trace.TracerProvider.shutdown(Otel.SDK.Trace.TracerProvider)

      Otel.API.Trace.with_span(
        tracer,
        "scenario-2-after-shutdown-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      assert empty?(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

  defp restart_with_env(env_vars) do
    prev = Map.new(env_vars, fn {k, _} -> {k, System.get_env(k)} end)
    Application.stop(:otel)
    for {k, v} <- env_vars, do: System.put_env(k, v)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {k, v} <- prev, do: restore_env(k, v)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  defp restart_for_shutdown_test do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      # The shutdown call inside the test left the global
      # provider in `:already_shutdown` state — restart so
      # subsequent test modules see a healthy SDK.
      Application.stop(:otel)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end
end
