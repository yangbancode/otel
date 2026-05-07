defmodule Otel.E2E.MetricsExemplarsTest do
  @moduledoc """
  E2E coverage for the hardcoded `:trace_based` exemplar
  filter + the reservoir defaults derived from instrument
  kind at registration time (histogram →
  `AlignedHistogramBucket`, otherwise `SimpleFixedSize`).

  Each scenario asserts on the resulting Mimir series **value**
  (count, sum, total) rather than just landing — a broken
  exemplar filter or a reservoir that swallows measurements
  would have passed the old land-only checks but fails these.

  Tracking matrix: `docs/e2e.md` §Metrics, scenarios 27–29.
  Scenarios 25 (always_on) and 26 (always_off) were removed
  when minikube hardcoded `exemplar_filter` to `:trace_based`
  — the filter behaviour is unit-tested in
  `test/otel/metrics/exemplar/filter_test.exs`.

  ## Exemplar payload assertions

  LGTM 0.26.0's `/api/v1/query_exemplars` exposure is
  configuration-dependent (Mimir's exemplar storage must be
  enabled and the OTLP receiver must forward exemplars), so
  this file does not assert on exemplar payloads themselves.
  Exemplar-payload correctness (count, trace_id presence,
  reservoir-state lifecycle) is covered by unit tests under
  `test/otel/metrics/exemplar/`.
  """

  use Otel.E2E.Case, async: false

  describe "filter :trace_based (default)" do
    test "27: trace_based records inside a sampled span — count matches adds",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_27_#{e2e_id}"
      counter = Otel.Metrics.Meter.create_counter(metric)

      Otel.Trace.with_span(
        "scenario-27-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          for _ <- 1..3, do: Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
        end
      )

      flush()

      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "#{metric}_total"))
      # 3 adds inside a sampled span → metric accumulates to 3.
      # If the trace_based filter erroneously dropped events at
      # the aggregation level (the right place would be the
      # exemplar reservoir, not the metric itself), this would
      # be lower.
      assert Mimir.value(result) == 3.0
    end
  end

  describe "reservoir defaults by aggregation kind" do
    test "28: AlignedHistogramBucket reservoir on a histogram — count and sum match",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_28_#{e2e_id}"
      hist = Otel.Metrics.Meter.create_histogram(metric)
      values = [1.0, 5.0, 25.0, 100.0]

      for v <- values, do: Otel.Metrics.Histogram.record(hist, v, %{"e2e.id" => e2e_id})

      flush()

      assert {:ok, [count_r | _]} = poll(Mimir.query(e2e_id, "#{metric}_count"))
      assert Mimir.value(count_r) == length(values) * 1.0

      assert {:ok, [sum_r | _]} = poll(Mimir.query(e2e_id, "#{metric}_sum"))
      assert Mimir.value(sum_r) == Enum.sum(values)
    end

    test "29: SimpleFixedSize reservoir on a non-histogram — total matches adds",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_29_#{e2e_id}"
      counter = Otel.Metrics.Meter.create_counter(metric)

      for _ <- 1..5, do: Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

      flush()

      assert {:ok, [result | _]} = poll(Mimir.query(e2e_id, "#{metric}_total"))
      assert Mimir.value(result) == 5.0
    end
  end
end
