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

  describe "default_temporality_mapping/0" do
    test "returns :cumulative for every instrument kind (OTLP default preference)" do
      mapping = Otel.API.Metrics.Instrument.default_temporality_mapping()

      for kind <- [
            :counter,
            :histogram,
            :gauge,
            :updown_counter,
            :observable_counter,
            :observable_gauge,
            :observable_updown_counter
          ] do
        assert Map.fetch!(mapping, kind) == :cumulative
      end
    end
  end

  describe "monotonic?/1" do
    test "returns true for Counter and Observable Counter (Sum kinds)" do
      assert Otel.API.Metrics.Instrument.monotonic?(:counter) == true
      assert Otel.API.Metrics.Instrument.monotonic?(:observable_counter) == true
    end

    test "returns false for UpDownCounter / Observable UpDownCounter (bidirectional Sum)" do
      assert Otel.API.Metrics.Instrument.monotonic?(:updown_counter) == false
      assert Otel.API.Metrics.Instrument.monotonic?(:observable_updown_counter) == false
    end

    test "returns false for Histogram and Gauge kinds (not Sum datapoints)" do
      assert Otel.API.Metrics.Instrument.monotonic?(:histogram) == false
      assert Otel.API.Metrics.Instrument.monotonic?(:gauge) == false
      assert Otel.API.Metrics.Instrument.monotonic?(:observable_gauge) == false
    end
  end
end
