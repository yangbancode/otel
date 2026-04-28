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
      assert {:ok, [_ | _] = results} = poll(Loki.query(e2e_id))

      # 4 attributes were sent (e2e.id + k1/k2/k3); limit was 2.
      # `e2e.id` survives (we filtered on it to find the record).
      # That leaves room for at most 1 of k1/k2/k3 in the
      # persisted record — the other two MUST have been dropped
      # at emit time. We don't assume which one survives because
      # the spec doesn't pin the order.
      payload = Jason.encode!(results)

      survivors = Enum.count(["k1", "k2", "k3"], &(payload =~ &1))

      assert survivors <= 1,
             "expected at most 1 of k1/k2/k3 to survive limit=2, got #{survivors}"
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
      assert {:ok, [_ | _] = results} = poll(Loki.query(e2e_id))

      # The original 16-char value MUST NOT appear anywhere in
      # the response. With limit=8 enforced, only the truncated
      # prefix `"01234567"` survives — the suffix `"89ABCDEF"`
      # is the unambiguous fingerprint of an *un*-truncated
      # value.
      payload = Jason.encode!(results)

      refute payload =~ "0123456789ABCDEF",
             "full 16-char value reached Loki — value-length limit not enforced"
    end
  end
end
