defmodule Otel.E2E.MetricsExemplarsTest do
  @moduledoc """
  E2E coverage for the hardcoded `:trace_based` exemplar
  filter + the reservoir defaults derived from aggregation
  kind by `Stream.resolve/1` (histogram →
  `AlignedHistogramBucket`, otherwise `SimpleFixedSize`).

  Tracking matrix: `docs/e2e.md` §Metrics, scenarios 27–29.
  Scenarios 25 (always_on) and 26 (always_off) were removed
  when minikube hardcoded `exemplar_filter` to `:trace_based`
  — the per-filter behaviour is unit-tested in
  `test/otel/metrics/metric_reader_test.exs`.

  ## Land-only signal

  LGTM 0.26.0's `/api/v1/query_exemplars` exposure is
  configuration-dependent (Mimir's exemplar storage must be
  enabled and the OTLP receiver must forward exemplars). The
  e2e signal is "the metric still lands under each filter /
  reservoir choice"; deeper detail (exemplar count, trace_id
  presence) is verified by the unit tests under
  `test/otel/sdk/metrics/exemplar/`.
  """

  use Otel.E2E.Case, async: false

  describe "filter :trace_based (default)" do
    test "27: trace_based records inside a sampled span", %{e2e_id: e2e_id} do
      meter = Otel.Metrics.MeterProvider.get_meter()
      metric = "e2e_scenario_27_#{e2e_id}"
      counter = Otel.Metrics.Meter.create_counter(meter, metric)

      Otel.Trace.with_span(
        "scenario-27-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
        end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "#{metric}_total"))
    end
  end

  describe "reservoir defaults by aggregation kind" do
    test "28: AlignedHistogramBucket reservoir on a histogram", %{e2e_id: e2e_id} do
      metric = "e2e_scenario_28_#{e2e_id}"

      meter = Otel.Metrics.MeterProvider.get_meter()
      hist = Otel.Metrics.Meter.create_histogram(meter, metric)

      for v <- [1.0, 5.0, 25.0, 100.0],
          do: Otel.Metrics.Histogram.record(hist, v, %{"e2e.id" => e2e_id})

      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "#{metric}_count"))
    end

    test "29: SimpleFixedSize reservoir on a non-histogram", %{e2e_id: e2e_id} do
      metric = "e2e_scenario_29_#{e2e_id}"

      meter = Otel.Metrics.MeterProvider.get_meter()
      counter = Otel.Metrics.Meter.create_counter(meter, metric)

      for _ <- 1..5,
          do: Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})

      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "#{metric}_total"))
    end
  end
end
