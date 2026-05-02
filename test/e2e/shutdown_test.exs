defmodule Otel.E2E.ShutdownTest do
  @moduledoc """
  E2E coverage for SDK shutdown semantics — calls made after a
  provider's `shutdown/1` MUST become no-ops and produce no
  records at the backend.

  Tracking matrix: `docs/e2e.md` §Global SDK control, scenario 2.
  """

  use Otel.E2E.Case, async: false

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

      tracer = Otel.Trace.TracerProvider.get_tracer(scope())
      :ok = Otel.Trace.TracerProvider.shutdown()

      Otel.Trace.with_span(
        tracer,
        "scenario-2-after-shutdown-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, []} = fetch(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

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
