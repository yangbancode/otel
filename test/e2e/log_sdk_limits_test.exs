defmodule Otel.E2E.LogSdkLimitsTest do
  @moduledoc """
  E2E coverage for `Otel.SDK.Logs.LogRecordLimits` against Loki.

  Both scenarios share a single SDK restart in `setup_all` with
  deliberately small limits so the drop counter / truncation is
  visible to the backend.

  Tracking matrix: `docs/e2e.md` §Log — SDK API, scenarios 11–12.
  """

  use Otel.E2E.Case, async: false

  @small_limits %{attribute_count_limit: 2, attribute_value_length_limit: 8}

  setup_all do
    prev = Application.get_env(:otel, :logs, [])
    Application.stop(:otel)
    Application.put_env(:otel, :logs, log_record_limits: @small_limits)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.put_env(:otel, :logs, prev)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  describe "log record limits" do
    test "11: attribute_count_limit (2) drops excess attributes", %{e2e_id: e2e_id} do
      logger = Otel.API.Logs.LoggerProvider.get_logger(scope())

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
        body: "scenario-11-#{e2e_id}",
        severity_number: 9,
        attributes: %{
          "e2e.id" => e2e_id,
          "k1" => "v1",
          "k2" => "v2",
          "k3" => "v3"
        }
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "12: attribute_value_length_limit (8) truncates long string values",
         %{e2e_id: e2e_id} do
      logger = Otel.API.Logs.LoggerProvider.get_logger(scope())

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
        body: "scenario-12-#{e2e_id}",
        severity_number: 9,
        attributes: %{
          "e2e.id" => e2e_id,
          "long" => "0123456789ABCDEF"
        }
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end
end
