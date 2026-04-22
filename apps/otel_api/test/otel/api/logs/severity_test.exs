defmodule Otel.API.Logs.SeverityTest do
  use ExUnit.Case, async: true

  # Per `logs/data-model-appendix.md` L806-L818 (Syslog row).
  # Distinct `:logger` levels within the same SeverityNumber
  # range (e.g. `:error` vs `:critical` in ERROR) must have
  # different numbers per spec L280-L283 — the regression
  # lock test below pins that constraint explicitly.
  describe "to_number/1" do
    test ":emergency → 21 (FATAL)" do
      assert Otel.API.Logs.Severity.to_number(:emergency) == 21
    end

    test ":alert → 19 (ERROR3)" do
      assert Otel.API.Logs.Severity.to_number(:alert) == 19
    end

    test ":critical → 18 (ERROR2)" do
      assert Otel.API.Logs.Severity.to_number(:critical) == 18
    end

    test ":error → 17 (ERROR)" do
      assert Otel.API.Logs.Severity.to_number(:error) == 17
    end

    test ":warning → 13 (WARN)" do
      assert Otel.API.Logs.Severity.to_number(:warning) == 13
    end

    test ":notice → 10 (INFO2)" do
      assert Otel.API.Logs.Severity.to_number(:notice) == 10
    end

    test ":info → 9 (INFO)" do
      assert Otel.API.Logs.Severity.to_number(:info) == 9
    end

    test ":debug → 5 (DEBUG)" do
      assert Otel.API.Logs.Severity.to_number(:debug) == 5
    end

    test "distinct levels in the ERROR range map to distinct numbers" do
      # Regression lock for spec L280-L283: three `:logger`
      # levels in the ERROR range (17-20) must be assigned
      # distinct numbers reflecting their relative severity
      # (:error < :critical < :alert).
      e = Otel.API.Logs.Severity.to_number(:error)
      c = Otel.API.Logs.Severity.to_number(:critical)
      a = Otel.API.Logs.Severity.to_number(:alert)
      assert e < c and c < a
      assert e == 17 and c == 18 and a == 19
    end
  end
end
