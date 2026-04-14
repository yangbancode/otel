defmodule Otel.SDK.Metrics.Aggregation.DropTest do
  use ExUnit.Case, async: true

  setup do
    tab = :ets.new(:test_metrics, [:set, :public])
    %{tab: tab}
  end

  describe "aggregate/4" do
    test "returns :ok and stores nothing", %{tab: tab} do
      assert :ok == Otel.SDK.Metrics.Aggregation.Drop.aggregate(tab, {:k, :s, %{}}, 42, %{})
      assert :ets.tab2list(tab) == []
    end
  end

  describe "collect/3" do
    test "always returns empty list", %{tab: tab} do
      assert [] == Otel.SDK.Metrics.Aggregation.Drop.collect(tab, {"name", :scope}, %{})
    end
  end
end
