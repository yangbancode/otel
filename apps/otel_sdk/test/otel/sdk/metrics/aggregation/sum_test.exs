defmodule Otel.SDK.Metrics.Aggregation.SumTest do
  use ExUnit.Case, async: true

  @scope %Otel.API.InstrumentationScope{name: "test"}

  setup do
    tab = :ets.new(:test_metrics, [:set, :public])
    %{tab: tab}
  end

  defp key(attrs \\ %{}), do: {"counter", @scope, attrs}

  describe "aggregate/4 with integers" do
    test "creates entry on first aggregate", %{tab: tab} do
      assert :ok == Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 5, %{})
      [{_key, int_val, float_val, _start}] = :ets.lookup(tab, key())
      assert int_val == 5
      assert float_val == 0.0
    end

    test "accumulates integer values", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 3, %{})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 7, %{})
      [{_key, int_val, _float_val, _start}] = :ets.lookup(tab, key())
      assert int_val == 10
    end
  end

  describe "aggregate/4 with floats" do
    test "creates entry on first aggregate", %{tab: tab} do
      assert :ok == Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 1.5, %{})
      [{_key, int_val, float_val, _start}] = :ets.lookup(tab, key())
      assert int_val == 0
      assert_in_delta float_val, 1.5, 0.001
    end

    test "accumulates float values", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 1.5, %{})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 2.5, %{})
      [{_key, _int_val, float_val, _start}] = :ets.lookup(tab, key())
      assert_in_delta float_val, 4.0, 0.001
    end
  end

  describe "aggregate/4 mixed int and float" do
    test "sums int and float independently", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 10, %{})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 2.5, %{})
      [{_key, int_val, float_val, _start}] = :ets.lookup(tab, key())
      assert int_val == 10
      assert_in_delta float_val, 2.5, 0.001
    end
  end

  describe "aggregate/4 with different attributes" do
    test "separate entries for different attributes", %{tab: tab} do
      k1 = key(%{method: "GET"})
      k2 = key(%{method: "POST"})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, k1, 1, %{})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, k2, 2, %{})
      assert length(:ets.tab2list(tab)) == 2
    end
  end

  describe "collect/3" do
    test "returns datapoints for stream", %{tab: tab} do
      k = key(%{method: "GET"})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, k, 10, %{})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, k, 5, %{})

      [dp] = Otel.SDK.Metrics.Aggregation.Sum.collect(tab, {"counter", @scope}, %{})
      assert dp.attributes == %{method: "GET"}
      assert dp.value == 15
      assert is_integer(dp.start_time)
      assert is_integer(dp.time)
    end

    test "returns multiple datapoints for different attributes", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(%{m: "GET"}), 1, %{})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(%{m: "POST"}), 2, %{})

      dps = Otel.SDK.Metrics.Aggregation.Sum.collect(tab, {"counter", @scope}, %{})
      assert length(dps) == 2
      values = Enum.map(dps, & &1.value) |> Enum.sort()
      assert values == [1, 2]
    end

    test "returns empty for non-existent stream", %{tab: tab} do
      assert [] == Otel.SDK.Metrics.Aggregation.Sum.collect(tab, {"other", @scope}, %{})
    end

    test "int+float sum is combined in collect", %{tab: tab} do
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 10, %{})
      Otel.SDK.Metrics.Aggregation.Sum.aggregate(tab, key(), 2.5, %{})
      [dp] = Otel.SDK.Metrics.Aggregation.Sum.collect(tab, {"counter", @scope}, %{})
      assert_in_delta dp.value, 12.5, 0.001
    end
  end
end
