defmodule Otel.SDK.Metrics.InstrumentTest do
  use ExUnit.Case, async: true

  describe "validate_name/1" do
    test "valid simple name" do
      assert {:ok, "requests"} = Otel.SDK.Metrics.Instrument.validate_name("requests")
    end

    test "valid name with allowed special chars" do
      assert {:ok, "http.server.request_duration"} =
               Otel.SDK.Metrics.Instrument.validate_name("http.server.request_duration")
    end

    test "valid name with dash and slash" do
      assert {:ok, "my-lib/counter"} =
               Otel.SDK.Metrics.Instrument.validate_name("my-lib/counter")
    end

    test "valid single char name" do
      assert {:ok, "a"} = Otel.SDK.Metrics.Instrument.validate_name("a")
    end

    test "valid 255 char name" do
      name = "a" <> String.duplicate("b", 254)
      assert {:ok, ^name} = Otel.SDK.Metrics.Instrument.validate_name(name)
    end

    test "nil name returns error" do
      assert {:error, _} = Otel.SDK.Metrics.Instrument.validate_name(nil)
    end

    test "empty name returns error" do
      assert {:error, _} = Otel.SDK.Metrics.Instrument.validate_name("")
    end

    test "name starting with digit returns error" do
      assert {:error, _} = Otel.SDK.Metrics.Instrument.validate_name("1counter")
    end

    test "name starting with underscore returns error" do
      assert {:error, _} = Otel.SDK.Metrics.Instrument.validate_name("_counter")
    end

    test "name exceeding 255 chars returns error" do
      name = "a" <> String.duplicate("b", 255)
      assert {:error, _} = Otel.SDK.Metrics.Instrument.validate_name(name)
    end

    test "name with invalid char returns error" do
      assert {:error, _} = Otel.SDK.Metrics.Instrument.validate_name("my counter")
    end
  end

  describe "downcased_name/1" do
    test "lowercases ASCII" do
      assert "requestcount" = Otel.SDK.Metrics.Instrument.downcased_name("RequestCount")
    end

    test "already lowercase unchanged" do
      assert "requests" = Otel.SDK.Metrics.Instrument.downcased_name("requests")
    end
  end

  describe "identical?/2" do
    test "identical instruments" do
      a = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      b = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      assert Otel.SDK.Metrics.Instrument.identical?(a, b)
    end

    test "case-insensitive name match" do
      a = %Otel.SDK.Metrics.Instrument{name: "Req", kind: :counter, unit: "1", description: "d"}
      b = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      assert Otel.SDK.Metrics.Instrument.identical?(a, b)
    end

    test "different kind not identical" do
      a = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}

      b = %Otel.SDK.Metrics.Instrument{
        name: "req",
        kind: :histogram,
        unit: "1",
        description: "d"
      }

      refute Otel.SDK.Metrics.Instrument.identical?(a, b)
    end

    test "different unit not identical" do
      a = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "d"}
      b = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "ms", description: "d"}
      refute Otel.SDK.Metrics.Instrument.identical?(a, b)
    end

    test "different description not identical" do
      a = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "a"}
      b = %Otel.SDK.Metrics.Instrument{name: "req", kind: :counter, unit: "1", description: "b"}
      refute Otel.SDK.Metrics.Instrument.identical?(a, b)
    end
  end

  describe "validate_advisory/2" do
    test "valid histogram boundaries" do
      assert [explicit_bucket_boundaries: [1, 5, 10]] =
               Otel.SDK.Metrics.Instrument.validate_advisory(:histogram,
                 explicit_bucket_boundaries: [1, 5, 10]
               )
    end

    test "empty boundaries valid for histogram" do
      assert [explicit_bucket_boundaries: []] =
               Otel.SDK.Metrics.Instrument.validate_advisory(:histogram,
                 explicit_bucket_boundaries: []
               )
    end

    test "boundaries for non-histogram dropped" do
      assert [] =
               Otel.SDK.Metrics.Instrument.validate_advisory(:counter,
                 explicit_bucket_boundaries: [1, 5, 10]
               )
    end

    test "unsorted boundaries dropped" do
      assert [] =
               Otel.SDK.Metrics.Instrument.validate_advisory(:histogram,
                 explicit_bucket_boundaries: [10, 5, 1]
               )
    end

    test "unknown advisory param dropped" do
      assert [] = Otel.SDK.Metrics.Instrument.validate_advisory(:counter, foo: :bar)
    end

    test "empty advisory returns empty" do
      assert [] = Otel.SDK.Metrics.Instrument.validate_advisory(:counter, [])
    end
  end
end
