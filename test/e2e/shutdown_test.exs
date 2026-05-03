defmodule Otel.E2E.ShutdownTest do
  @moduledoc """
  E2E coverage for SDK shutdown semantics — `Application.stop(:otel)`
  drives the supervisor down, the BatchProcessor's `terminate/2`
  drains pending data, and the exporter ships it before exit.
  Lifecycle is delegated to OTP — there is no manual `shutdown/1`
  on Provider modules.

  Tracking matrix: `docs/e2e.md` §Global SDK control, scenario 2.
  """

  use Otel.E2E.Case, async: false

  describe "Application.stop drains pending data" do
    test "2: span emitted just before Application.stop still reaches Tempo",
         %{e2e_id: e2e_id} do
      restart_for_shutdown_test()

      Otel.Trace.with_span(
        "scenario-2-pre-stop-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      # `Application.stop(:otel)` triggers the supervisor's child
      # termination, which routes through SpanProcessor.terminate/2
      # → drain queue + exporter.shutdown.
      Application.stop(:otel)

      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

  defp restart_for_shutdown_test do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      # The Application.stop in the test left the SDK down — restart
      # so subsequent test modules see a healthy SDK.
      Application.ensure_all_started(:otel)
    end)

    :ok
  end
end
