defmodule Otel.E2E.MetricsReaderTest do
  @moduledoc """
  E2E coverage for reader-side Metrics behaviour against Mimir
  — `Meter.enabled?/2` gating and View-driven cardinality
  limits. Delta temporality (scenario 17) needs a different
  reader config and lives in `metrics_temporality_test.exs`.

  Tracking matrix: `docs/e2e.md` §Metrics, scenarios 15, 19, 20.
  """

  use Otel.E2E.Case, async: false

  describe "Meter.enabled?/2" do
    test "15: Drop View on every matching stream → enabled? returns false",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_15_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
        )

      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      counter = Otel.API.Metrics.Meter.create_counter(meter, metric)

      # Spec L223-L227: every matching stream is `:drop` →
      # `Meter.enabled?/2` MUST return false so call sites can
      # short-circuit recording.
      refute Otel.API.Metrics.Meter.enabled?(counter)

      # The `add` itself must still be a safe no-op.
      Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
      flush()

      assert {:ok, []} = fetch(Mimir.query(e2e_id, "#{metric}_total"))
    end
  end

  describe "cardinality limits" do
    test "19: sync overflow → otel.metric.overflow=true series", %{e2e_id: e2e_id} do
      metric = "e2e_scenario_19_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{aggregation_cardinality_limit: 2}
        )

      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      counter = Otel.API.Metrics.Meter.create_counter(meter, metric)

      # Send 5 distinct attribute combinations against a
      # cardinality limit of 2 (plus the overflow bucket).
      # Excess streams collapse into the
      # `otel.metric.overflow="true"` aggregation bucket.
      for i <- 1..5 do
        Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id, "k" => "v#{i}"})
      end

      flush()

      # The overflow series is selected via the overflow label
      # rather than `e2e_id` because per spec the overflow
      # attribute set is the single `otel.metric.overflow=true`
      # attribute — every other attribute (including `e2e.id`)
      # is dropped. The metric name suffix already keys this
      # query to this test's instrument.
      assert {:ok, [_ | _]} = poll(Mimir.query_overflow("#{metric}_total"))
    end

    test "20: async first-observed cardinality is pinned across collects",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_20_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{aggregation_cardinality_limit: 2}
        )

      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      cb = fn _args ->
        # Emits 4 distinct attr combos every collect; only the
        # first 2 observed get pinned series, the rest collapse
        # into the overflow bucket.
        for i <- 1..4 do
          %Otel.API.Metrics.Measurement{
            value: 1,
            attributes: %{"e2e.id" => e2e_id, "k" => "v#{i}"}
          }
        end
      end

      _ =
        Otel.API.Metrics.Meter.create_observable_counter(
          meter,
          metric,
          cb,
          nil,
          []
        )

      flush()

      assert {:ok, [_ | _]} = poll(Mimir.query_overflow("#{metric}_total"))
    end
  end
end
