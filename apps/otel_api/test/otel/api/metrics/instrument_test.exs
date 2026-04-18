defmodule Otel.API.Metrics.InstrumentTest do
  use ExUnit.Case, async: true

  describe "downcased_name/1" do
    test "lowercases ASCII" do
      assert "requestcount" = Otel.API.Metrics.Instrument.downcased_name("RequestCount")
    end

    test "already lowercase unchanged" do
      assert "requests" = Otel.API.Metrics.Instrument.downcased_name("requests")
    end
  end

  describe "identical?/2" do
    test "identical instruments" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      b = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      assert Otel.API.Metrics.Instrument.identical?(a, b)
    end

    test "case-insensitive name match" do
      a = %Otel.API.Metrics.Instrument{name: "Req", kind: :counter, unit: "1", description: "d"}
      b = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      assert Otel.API.Metrics.Instrument.identical?(a, b)
    end

    test "different kind not identical" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}

      b = %Otel.API.Metrics.Instrument{
        name: "req",
        kind: :histogram,
        unit: "1",
        description: "d"
      }

      refute Otel.API.Metrics.Instrument.identical?(a, b)
    end

    test "different unit not identical" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      b = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "ms", description: "d"}
      refute Otel.API.Metrics.Instrument.identical?(a, b)
    end

    test "different description not identical" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "a"}
      b = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "b"}
      refute Otel.API.Metrics.Instrument.identical?(a, b)
    end
  end

  describe "conflict_type/2" do
    test "description_only when only description differs" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "a"}
      b = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "b"}
      assert :description_only == Otel.API.Metrics.Instrument.conflict_type(a, b)
    end

    test "distinguishable when kind differs" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "a"}

      b = %Otel.API.Metrics.Instrument{
        name: "req",
        kind: :histogram,
        unit: "1",
        description: "a"
      }

      assert :distinguishable == Otel.API.Metrics.Instrument.conflict_type(a, b)
    end

    test "unresolvable when unit differs" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "a"}
      b = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "ms", description: "a"}
      assert :unresolvable == Otel.API.Metrics.Instrument.conflict_type(a, b)
    end

    test "distinguishable when kind differs but unit matches" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "a"}

      b = %Otel.API.Metrics.Instrument{
        name: "req",
        kind: :histogram,
        unit: "1",
        description: "b"
      }

      assert :distinguishable == Otel.API.Metrics.Instrument.conflict_type(a, b)
    end

    test "distinguishable when both kind and unit differ" do
      a = %Otel.API.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "a"}

      b = %Otel.API.Metrics.Instrument{
        name: "req",
        kind: :histogram,
        unit: "ms",
        description: "a"
      }

      assert :distinguishable == Otel.API.Metrics.Instrument.conflict_type(a, b)
    end
  end
end
