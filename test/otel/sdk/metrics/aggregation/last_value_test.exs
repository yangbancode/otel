defmodule Otel.SDK.Metrics.Aggregation.LastValueTest do
  use ExUnit.Case, async: true

  @scope %Otel.API.InstrumentationScope{name: "test"}

  setup do
    tab = :ets.new(:test_metrics, [:set, :public])
    %{tab: tab}
  end

  defp key(attrs \\ %{}), do: {"gauge", @scope, nil, attrs}

  describe "aggregate/4" do
    test "stores first value", %{tab: tab} do
      assert :ok == Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(), 42, %{})
      [{_key, value, _ts, _start}] = :ets.lookup(tab, key())
      assert value == 42
    end

    test "overwrites with latest value", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(), 10, %{})
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(), 20, %{})
      [{_key, value, _ts, _start}] = :ets.lookup(tab, key())
      assert value == 20
    end

    test "works with float values", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(), 3.14, %{})
      [{_key, value, _ts, _start}] = :ets.lookup(tab, key())
      assert_in_delta value, 3.14, 0.001
    end

    test "separate entries for different attributes", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(%{"host" => "a"}), 1, %{})
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(%{"host" => "b"}), 2, %{})
      assert length(:ets.tab2list(tab)) == 2
    end
  end

  describe "collect/3" do
    test "returns last value", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(), 10, %{})
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(), 99, %{})

      [dp] = Otel.SDK.Metrics.Aggregation.LastValue.collect(tab, {"gauge", @scope}, %{})
      assert dp.value == 99
      assert dp.attributes == %{}
    end

    test "returns multiple datapoints", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(%{"h" => "a"}), 1, %{})
      Otel.SDK.Metrics.Aggregation.LastValue.aggregate(tab, key(%{"h" => "b"}), 2, %{})

      dps = Otel.SDK.Metrics.Aggregation.LastValue.collect(tab, {"gauge", @scope}, %{})
      assert length(dps) == 2
    end

    test "returns empty for non-existent stream", %{tab: tab} do
      assert [] == Otel.SDK.Metrics.Aggregation.LastValue.collect(tab, {"other", @scope}, %{})
    end
  end
end
