defmodule Otel.E2E.ResourceTest do
  @moduledoc """
  E2E coverage for SDK Resource configuration against Tempo.

  The SDK reads no `OTEL_*` env vars and no Mix Config. Resource
  flows in via the standard Mix release env vars `RELEASE_NAME`
  and `RELEASE_VSN` at runtime — automatically set by Mix
  release boot scripts.

  Tracking matrix: `docs/e2e.md` §Resource, scenario 4.
  """

  use Otel.E2E.Case, async: false

  describe "Resource configuration" do
    test "4: RELEASE_NAME flows to Tempo via service.name", %{e2e_id: e2e_id} do
      restart_with_release_env("e2e_resource_app", "1.0.0")

      emit_span("scenario-4-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

  defp restart_with_release_env(name, vsn) do
    prev_name = System.get_env("RELEASE_NAME")
    prev_vsn = System.get_env("RELEASE_VSN")

    Application.stop(:otel)
    System.put_env("RELEASE_NAME", name)
    System.put_env("RELEASE_VSN", vsn)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)

      case prev_name do
        nil -> System.delete_env("RELEASE_NAME")
        v -> System.put_env("RELEASE_NAME", v)
      end

      case prev_vsn do
        nil -> System.delete_env("RELEASE_VSN")
        v -> System.put_env("RELEASE_VSN", v)
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
