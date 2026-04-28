defmodule Otel.E2E.ResourceTest do
  @moduledoc """
  E2E coverage for SDK Resource configuration against Tempo.

  Each scenario installs a different `OTEL_*` env var or
  `:resource` Mix Config value, restarts the SDK, emits a span,
  and asserts the resource attribute survives ingest. The tag
  filter on `e2e.id` keeps the resource search scoped to the
  test that emitted the span.

  Tracking matrix: `docs/e2e.md` §Resource, scenarios 1–4.
  """

  use Otel.E2E.Case, async: false

  describe "Resource configuration" do
    test "1: OTEL_SERVICE_NAME env var sets service.name on emitted spans",
         %{e2e_id: e2e_id} do
      restart_with_env(%{"OTEL_SERVICE_NAME" => "svc-1-#{e2e_id}"})
      emit_span("scenario-1-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

    test "2: OTEL_RESOURCE_ATTRIBUTES env var attaches custom resource attrs",
         %{e2e_id: e2e_id} do
      restart_with_env(%{
        "OTEL_RESOURCE_ATTRIBUTES" => "deployment.environment=test,test.run=#{e2e_id}"
      })

      emit_span("scenario-2-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

    test "3: OTEL_SERVICE_NAME wins over a service.name in OTEL_RESOURCE_ATTRIBUTES",
         %{e2e_id: e2e_id} do
      # Spec MUST: when both are set, OTEL_SERVICE_NAME takes
      # precedence for `service.name`.
      restart_with_env(%{
        "OTEL_SERVICE_NAME" => "winner-3-#{e2e_id}",
        "OTEL_RESOURCE_ATTRIBUTES" => "service.name=loser-3-#{e2e_id},test.run=#{e2e_id}"
      })

      emit_span("scenario-3-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

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
