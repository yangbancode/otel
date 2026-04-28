defmodule Otel.E2E.MetricsAsyncTest do
  @moduledoc """
  E2E coverage for asynchronous (observable) Metrics instruments
  against Mimir.

  Tracking matrix: `docs/e2e.md` §Metrics, scenarios 9–13. Each
  scenario installs an inline callback that emits one
  `%Measurement{}` per tag (or per shared instrument) so the
  PeriodicExporting reader picks them up on the `flush/0`-driven
  collect.
  """

  use Otel.E2E.Case, async: false

  describe "observable instruments" do
    test "9: ObservableCounter callback feeds the counter", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      cb = fn _args ->
        [%Otel.API.Metrics.Measurement{value: 7, attributes: %{"e2e.id" => e2e_id}}]
      end

      _ =
        Otel.API.Metrics.Meter.create_observable_counter(
          meter,
          "e2e_scenario_9_#{e2e_id}",
          cb,
          nil,
          []
        )

      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_9_#{e2e_id}_total"))
    end

    test "10: ObservableUpDownCounter callback feeds multi-attr series", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      cb = fn _args ->
        [
          %Otel.API.Metrics.Measurement{
            value: 1,
            attributes: %{"e2e.id" => e2e_id, "host" => "a"}
          },
          %Otel.API.Metrics.Measurement{
            value: -1,
            attributes: %{"e2e.id" => e2e_id, "host" => "b"}
          }
        ]
      end

      _ =
        Otel.API.Metrics.Meter.create_observable_updown_counter(
          meter,
          "e2e_scenario_10_#{e2e_id}",
          cb,
          nil,
          []
        )

      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_10_#{e2e_id}"))
    end

    test "11: ObservableGauge callback feeds the gauge", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      cb = fn _args ->
        [%Otel.API.Metrics.Measurement{value: 99, attributes: %{"e2e.id" => e2e_id}}]
      end

      _ =
        Otel.API.Metrics.Meter.create_observable_gauge(
          meter,
          "e2e_scenario_11_#{e2e_id}",
          cb,
          nil,
          []
        )

      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_11_#{e2e_id}"))
    end
  end

  describe "callback registration" do
    test "12: register_callback/5 fans out measurements across instruments",
         %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      gauge_a =
        Otel.API.Metrics.Meter.create_observable_gauge(
          meter,
          "e2e_scenario_12_a_#{e2e_id}"
        )

      gauge_b =
        Otel.API.Metrics.Meter.create_observable_gauge(
          meter,
          "e2e_scenario_12_b_#{e2e_id}"
        )

      cb = fn _args ->
        [
          {gauge_a, %Otel.API.Metrics.Measurement{value: 1, attributes: %{"e2e.id" => e2e_id}}},
          {gauge_b, %Otel.API.Metrics.Measurement{value: 2, attributes: %{"e2e.id" => e2e_id}}}
        ]
      end

      _reg = Otel.API.Metrics.Meter.register_callback(meter, [gauge_a, gauge_b], cb, nil, [])

      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_12_a_#{e2e_id}"))
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_12_b_#{e2e_id}"))
    end

    test "13: unregister_callback/1 stops further measurements", %{e2e_id: e2e_id} do
      meter = Otel.API.Metrics.MeterProvider.get_meter(scope())

      gauge =
        Otel.API.Metrics.Meter.create_observable_gauge(
          meter,
          "e2e_scenario_13_#{e2e_id}"
        )

      cb = fn _args ->
        [{gauge, %Otel.API.Metrics.Measurement{value: 1, attributes: %{"e2e.id" => e2e_id}}}]
      end

      reg = Otel.API.Metrics.Meter.register_callback(meter, [gauge], cb, nil, [])
      flush()
      assert {:ok, [_ | _]} = poll(Mimir.query(e2e_id, "e2e_scenario_13_#{e2e_id}"))

      :ok = Otel.API.Metrics.Meter.unregister_callback(reg)
      # Verifying *absence* of further values is brittle (Mimir
      # keeps the existing series and timestamps), so the
      # post-unregister check just confirms the call succeeded
      # and didn't crash. The unit-test suite exercises the
      # actual "no further callback invocations" contract.
    end
  end
end
