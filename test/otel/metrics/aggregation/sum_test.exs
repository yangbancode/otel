defmodule Otel.Metrics.Aggregation.SumTest do
  use ExUnit.Case, async: true

  @scope Otel.InstrumentationScope.new(%{name: "test"})

  setup do
    %{tab: :ets.new(:sum_test, [:set, :public])}
  end

  defp key(attrs \\ %{}), do: {"counter", @scope, attrs}

  # Spec metrics/sdk.md L1247-L1259 — Sum accumulates per attribute
  # set, keeping integer and float buckets separate so int + float
  # measurements can coexist without precision loss.

  describe "aggregate/4" do
    test "accumulates int and float values into separate buckets per stream", %{tab: tab} do
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(), 3, %{})
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(), 7, %{})
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(), 1.5, %{})
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(), 2.5, %{})

      [{_key, int_val, float_val, _start}] = :ets.lookup(tab, key())
      assert int_val == 10
      assert_in_delta float_val, 4.0, 0.001
    end

    test "keeps separate entries per attribute set", %{tab: tab} do
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(%{"m" => "GET"}), 1, %{})
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(%{"m" => "POST"}), 2, %{})

      assert length(:ets.tab2list(tab)) == 2
    end
  end

  describe "collect/3" do
    test "returns one datapoint per attribute set; combines int+float into a single value" do
      tab = :ets.new(:sum_collect, [:set, :public])
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(%{"m" => "GET"}), 10, %{})
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(%{"m" => "GET"}), 2.5, %{})
      Otel.Metrics.Aggregation.Sum.aggregate(tab, key(%{"m" => "POST"}), 5, %{})

      dps = Otel.Metrics.Aggregation.Sum.collect(tab, {"counter", @scope}, %{})
      assert length(dps) == 2

      get_dp = Enum.find(dps, &(&1.attributes == %{"m" => "GET"}))
      post_dp = Enum.find(dps, &(&1.attributes == %{"m" => "POST"}))

      assert_in_delta get_dp.value, 12.5, 0.001
      assert post_dp.value == 5
      assert is_integer(get_dp.start_time)
      assert is_integer(get_dp.time)
    end

    test "empty result for an unknown stream key", %{tab: tab} do
      assert [] = Otel.Metrics.Aggregation.Sum.collect(tab, {"other", @scope}, %{})
    end
  end
end
