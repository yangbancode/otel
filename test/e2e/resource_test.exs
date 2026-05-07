defmodule Otel.E2E.ResourceTest do
  @moduledoc """
  E2E coverage for SDK Resource configuration against Tempo.

  The SDK reads no `OTEL_*` env vars and no Mix Config besides
  `config :otel, :otp_app`. The configured atom drives `service.name`
  via `Atom.to_string/1` and `service.version` via
  `Application.spec(:my_app, :vsn)`.

  The scenario uses `:otel` itself as the test app — it's
  always loaded in the suite and its vsn is the SDK's own
  `mix.exs` `version:`, which is exactly the contract we want
  to verify (single source of truth).

  Tracking matrix: `docs/e2e.md` §Resource, scenario 4.
  """

  use Otel.E2E.Case, async: false

  describe "Resource configuration" do
    test "4: :otp_app config flows to Tempo via service.name and service.version",
         %{e2e_id: e2e_id} do
      restart_with_app_config(:otel)

      emit_span("scenario-4-#{e2e_id}", e2e_id)

      # Pull the full OTLP-shaped trace and assert the Resource
      # carries the configured service.name / service.version.
      # Land-only would pass even if the SDK ignored the :otp_app
      # config entirely.
      assert {:ok, [%{"traceID" => trace_id_hex} | _]} = poll(Tempo.search(e2e_id))
      {:ok, body} = HTTP.get(Tempo.get_trace(trace_id_hex))
      {:ok, %{"batches" => batches}} = Jason.decode(body)

      [resource | _] =
        Enum.map(batches, & &1["resource"])
        |> Enum.reject(&is_nil/1)

      assert resource_attribute(resource, "service.name") == "otel"

      expected_vsn = :otel |> Application.spec(:vsn) |> List.to_string()
      assert resource_attribute(resource, "service.version") == expected_vsn
    end
  end

  # ---- helpers ----

  defp restart_with_app_config(app) do
    prev_app = Application.get_env(:otel, :otp_app)

    Application.stop(:otel)
    Application.put_env(:otel, :otp_app, app)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)

      case prev_app do
        nil -> Application.delete_env(:otel, :otp_app)
        v -> Application.put_env(:otel, :otp_app, v)
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

  # OTLP/JSON resource shape:
  # `%{"attributes" => [%{"key" => k, "value" => %{"stringValue" => v}}, ...]}`
  defp resource_attribute(%{"attributes" => attrs}, key) do
    case Enum.find(attrs, &(&1["key"] == key)) do
      nil -> nil
      %{"value" => %{"stringValue" => v}} -> v
      %{"value" => %{"intValue" => v}} when is_binary(v) -> String.to_integer(v)
      %{"value" => %{"intValue" => v}} -> v
    end
  end
end
