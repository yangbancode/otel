defmodule Otel.E2E.ResourceTest do
  @moduledoc """
  E2E coverage for SDK Resource configuration against Tempo.

  The SDK reads no `OTEL_*` env vars — Resource flows in via
  the top-level `config :otel, resource: %{...}` map.

  Tracking matrix: `docs/e2e.md` §Resource, scenario 4.
  """

  use Otel.E2E.Case, async: false

  describe "Resource configuration" do
    test "4: top-level :resource map flows to Tempo via service.name", %{e2e_id: e2e_id} do
      restart_with_resource(%{
        "service.name" => "mix-svc-4-#{e2e_id}",
        "deployment.environment" => "mix-test"
      })

      emit_span("scenario-4-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

  defp restart_with_resource(attrs) do
    prev = Application.get_env(:otel, :resource, %{})
    Application.stop(:otel)
    Application.put_env(:otel, :resource, attrs)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.put_env(:otel, :resource, prev)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  defp emit_span(name, e2e_id) do
    tracer = Otel.Trace.TracerProvider.get_tracer(scope())

    Otel.Trace.with_span(
      tracer,
      name,
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush()
  end
end
