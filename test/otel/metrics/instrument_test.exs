defmodule Otel.Metrics.InstrumentTest do
  use ExUnit.Case, async: true

  describe "downcased_name/1" do
    # Spec metrics/sdk.md L945-L958 MUST: identifier comparison
    # MUST be case-insensitive (ASCII lowercase fold).
    test "lowercases ASCII characters; pure-lowercase input is unchanged" do
      assert Otel.Metrics.Instrument.downcased_name("RequestCount") == "requestcount"
      assert Otel.Metrics.Instrument.downcased_name("requests") == "requests"
    end
  end

  describe "monotonic?/1" do
    # Per the moduledoc Divergences note: this predicate feeds OTLP's
    # `Sum.is_monotonic`, so true iff the kind produces a monotonic
    # Sum (Counter only — async kinds are not implemented).
    test "true for Sum-monotonic kinds" do
      assert Otel.Metrics.Instrument.monotonic?(:counter)
    end

    test "false for every other kind (UpDownCounter, Histogram, Gauge)" do
      refute Otel.Metrics.Instrument.monotonic?(:updown_counter)
      refute Otel.Metrics.Instrument.monotonic?(:histogram)
      refute Otel.Metrics.Instrument.monotonic?(:gauge)
    end
  end
end
