defmodule Otel.E2E.ResourceTest do
  @moduledoc """
  E2E coverage for SDK Resource configuration against Tempo.

  The SDK reads no `OTEL_*` env vars — Resource flows in via
  `config :otel, trace: [resource: ...]`. (Bridging
  `OTEL_SERVICE_NAME` / `OTEL_RESOURCE_ATTRIBUTES` from
  `runtime.exs` is the user's responsibility; see
  `docs/configuration.md`.)

  Tracking matrix: `docs/e2e.md` §Resource, scenario 4.
  """

  use Otel.E2E.Case, async: false

  describe "Resource configuration" do
    test "4: Mix Config :resource overrides the default", %{e2e_id: e2e_id} do
      restart_with_pillar(:trace,
        resource: %Otel.SDK.Resource{
          attributes: %{
            "service.name" => "mix-svc-4-#{e2e_id}",
            "deployment.environment" => "mix-test"
          },
          schema_url: ""
        }
      )

      emit_span("scenario-4-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

  defp restart_with_pillar(pillar, opts) do
    prev = Application.get_env(:otel, pillar, [])
    Application.stop(:otel)
    Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.put_env(:otel, pillar, prev)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  defp emit_span(name, e2e_id) do
    tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())

    Otel.API.Trace.with_span(
      tracer,
      name,
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush()
  end
end
