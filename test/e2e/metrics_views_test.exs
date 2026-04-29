defmodule Otel.E2E.MetricsViewsTest do
  @moduledoc """
  E2E coverage for `Otel.SDK.Metrics.View` against Mimir.

  Each scenario installs a different View on the global
  MeterProvider (via `add_view/3`), creates an instrument
  whose name matches the View's criteria, records a sample,
  and asserts the View's stream-config field reaches Mimir.

  Tracking matrix: `docs/e2e.md` §Metrics, scenarios 6, 7,
  14, 22-24.
  """

  use Otel.E2E.Case, async: false

  describe "View — stream identity" do
    test "22: View renames the instrument", %{e2e_id: e2e_id} do
      original = "e2e_scenario_22_#{e2e_id}"
      renamed = "renamed_22_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: original},
          %{name: renamed}
        )

      record_counter(original, e2e_id)

      # Original name has no series; the renamed one carries it.
      assert {:ok, []} = fetch(Mimir.query(e2e_id, "#{original}_total"))
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "#{renamed}_total"))
    end

    test "23: View `attribute_keys: {:include, ...}` filters labels",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_23_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{attribute_keys: {:include, ["e2e.id"]}}
        )

      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      counter = Otel.API.Metrics.Meter.create_counter(meter, metric)

      Otel.API.Metrics.Counter.add(counter, 1, %{
        "e2e.id" => e2e_id,
        "host" => "filtered-out",
        "region" => "filtered-out"
      })

      flush()

      assert {:ok, [series | _]} = poll(Mimir.query(e2e_id, "#{metric}_total"))
      labels = series["metric"] || %{}

      # `host` / `region` were stripped by the View; only
      # `e2e.id` (renamed to `e2e_id` by Mimir's label
      # sanitizer) survives among the user attrs.
      refute Map.has_key?(labels, "host")
      refute Map.has_key?(labels, "region")
    end
  end

  describe "View — aggregation override" do
    test "24: View promotes a Counter to histogram aggregation", %{e2e_id: e2e_id} do
      metric = "e2e_scenario_24_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{aggregation: Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram}
        )

      record_counter(metric, e2e_id)

      # Histogram aggregation surfaces `_count` / `_sum` /
      # `_bucket` series; the original `_total` series is gone.
      assert {:ok, []} = fetch(Mimir.query(e2e_id, "#{metric}_total"))
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "#{metric}_count"))
    end

    test "6: histogram with `aggregation_options: %{record_min_max: false}`",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_6_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{
            aggregation: Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram,
            aggregation_options: %{record_min_max: false}
          }
        )

      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      hist = Otel.API.Metrics.Meter.create_histogram(meter, metric)
      Otel.API.Metrics.Histogram.record(hist, 5, %{"e2e.id" => e2e_id})
      flush()

      # Histogram lands. min/max suppression is an OTLP-level
      # contract (the SDK omits the `min` / `max` fields on
      # the data point); Prometheus exposition doesn't surface
      # min/max as series, so the e2e signal here is just
      # "histogram lands with the View applied".
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "#{metric}_count"))
    end

    test "7: View promotes histogram to base2 exponential aggregation",
         %{e2e_id: e2e_id} do
      metric = "e2e_scenario_7_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{aggregation: Otel.SDK.Metrics.Aggregation.Base2ExponentialBucketHistogram}
        )

      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
      hist = Otel.API.Metrics.Meter.create_histogram(meter, metric)

      for v <- [1.0, 2.0, 4.0, 8.0],
          do: Otel.API.Metrics.Histogram.record(hist, v, %{"e2e.id" => e2e_id})

      flush()

      # Mimir's OTLP receiver converts exponential histograms
      # to Prometheus native histograms in LGTM 0.26.0; native
      # histograms expose a single series under the bare metric
      # name (envelope `histogram` on the `/api/v1/query`
      # response), not the classic `_count` / `_sum` / `_bucket`
      # decomposition. Landing on the bare name is the
      # conservative cross-version signal.
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, metric))
    end
  end

  describe "View — drop" do
    test "14: drop aggregation suppresses the series", %{e2e_id: e2e_id} do
      metric = "e2e_scenario_14_#{e2e_id}"

      :ok =
        Otel.SDK.Metrics.MeterProvider.add_view(
          Otel.SDK.Metrics.MeterProvider,
          %{name: metric},
          %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
        )

      record_counter(metric, e2e_id)

      # Nothing reaches Mimir.
      assert {:ok, []} = fetch(Mimir.query(e2e_id, "#{metric}_total"))
    end
  end

  # ---- helpers ----

  defp record_counter(name, e2e_id) do
    meter = Otel.API.Metrics.MeterProvider.get_meter(scope())
    counter = Otel.API.Metrics.Meter.create_counter(meter, name)
    Otel.API.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
    flush()
  end
end
