defmodule Otel.Metrics.Aggregation.LastValueTest do
  use ExUnit.Case, async: true

  @scope %Otel.InstrumentationScope{name: "test"}

  setup do
    %{tab: :ets.new(:last_value_test, [:set, :public])}
  end

  defp key(attrs \\ %{}), do: {"gauge", @scope, nil, attrs}

  # Spec metrics/sdk.md L1240-L1245 — LastValue keeps the most recent
  # measurement for each attribute set.

  describe "aggregate/4" do
    test "stores the latest value, overwriting any prior one for the same attrs", %{tab: tab} do
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(), 10, %{})
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(), 20, %{})
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(), 3.14, %{})

      [{_key, value, _ts, _start}] = :ets.lookup(tab, key())
      assert_in_delta value, 3.14, 0.001
    end

    test "keeps separate entries per attribute set", %{tab: tab} do
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(%{"h" => "a"}), 1, %{})
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(%{"h" => "b"}), 2, %{})

      assert length(:ets.tab2list(tab)) == 2
    end
  end

  describe "collect/3" do
    test "returns one datapoint per attribute set with the latest value" do
      tab = :ets.new(:lv_collect, [:set, :public])
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(), 10, %{})
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(), 99, %{})
      Otel.Metrics.Aggregation.LastValue.aggregate(tab, key(%{"h" => "a"}), 1, %{})

      dps = Otel.Metrics.Aggregation.LastValue.collect(tab, {"gauge", @scope}, %{})
      assert length(dps) == 2
      assert Enum.find(dps, &(&1.attributes == %{})).value == 99
      assert Enum.find(dps, &(&1.attributes == %{"h" => "a"})).value == 1
    end

    test "empty result for an unknown stream key", %{tab: tab} do
      assert [] = Otel.Metrics.Aggregation.LastValue.collect(tab, {"other", @scope}, %{})
    end
  end
end
