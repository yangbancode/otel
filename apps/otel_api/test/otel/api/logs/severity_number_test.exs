defmodule Otel.API.Logs.SeverityNumberTest do
  use ExUnit.Case, async: true

  # Per `logs/data-model-appendix.md` L806-L818 (Syslog row).
  # Distinct Syslog levels within the same range (e.g. `:error`
  # vs `:critical` in ERROR) must have different SeverityNumbers
  # per spec L280-L283 — that constraint is what this test
  # locks down.
  describe "from_syslog_level/1" do
    test ":emergency → 21 (FATAL)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:emergency) == 21
    end

    test ":alert → 19 (ERROR3)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:alert) == 19
    end

    test ":critical → 18 (ERROR2)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:critical) == 18
    end

    test ":error → 17 (ERROR)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:error) == 17
    end

    test ":warning → 13 (WARN)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:warning) == 13
    end

    test ":notice → 10 (INFO2)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:notice) == 10
    end

    test ":info → 9 (INFO)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:info) == 9
    end

    test ":debug → 5 (DEBUG)" do
      assert Otel.API.Logs.SeverityNumber.from_syslog_level(:debug) == 5
    end

    test "distinct levels in the ERROR range map to distinct numbers" do
      # Regression lock for spec L280-L283: three levels in the
      # ERROR range (17-20) must be assigned distinct values
      # reflecting their relative severity (:error < :critical <
      # :alert).
      e = Otel.API.Logs.SeverityNumber.from_syslog_level(:error)
      c = Otel.API.Logs.SeverityNumber.from_syslog_level(:critical)
      a = Otel.API.Logs.SeverityNumber.from_syslog_level(:alert)
      assert e < c and c < a
      assert e == 17 and c == 18 and a == 19
    end
  end
end
