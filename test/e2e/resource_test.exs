defmodule Otel.E2E.ResourceTest do
  @moduledoc """
  E2E coverage for SDK Resource configuration against Tempo.

  The SDK reads no `OTEL_*` env vars — Resource flows in via
  the top-level `config :otel, otp_app: :my_app` atom, which
  derives `service.name` and `service.version`.

  Tracking matrix: `docs/e2e.md` §Resource, scenario 4.
  """

  use Otel.E2E.Case, async: false

  describe "Resource configuration" do
    test "4: top-level :otp_app flows to Tempo via service.name", %{e2e_id: e2e_id} do
      restart_with_otp_app(:otel)

      emit_span("scenario-4-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

  defp restart_with_otp_app(app) do
    prev = Application.get_env(:otel, :otp_app)
    Application.stop(:otel)
    Application.put_env(:otel, :otp_app, app)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)

      case prev do
        nil -> Application.delete_env(:otel, :otp_app)
        app -> Application.put_env(:otel, :otp_app, app)
      end

      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  defp emit_span(name, e2e_id) do
    Otel.Trace.with_span(
      name,
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush()
  end
end
