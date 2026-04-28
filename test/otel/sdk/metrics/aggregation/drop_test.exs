defmodule Otel.SDK.Metrics.Aggregation.DropTest do
  use ExUnit.Case, async: true

  # Spec metrics/sdk.md L1287-L1289 — Drop discards every measurement
  # and yields nothing on collect.
  test "aggregate/4 stores nothing; collect/3 always returns []" do
    tab = :ets.new(:drop_test, [:set, :public])

    assert :ok = Otel.SDK.Metrics.Aggregation.Drop.aggregate(tab, {:k, :s, %{}}, 42, %{})
    assert :ets.tab2list(tab) == []
    assert [] = Otel.SDK.Metrics.Aggregation.Drop.collect(tab, {"name", :scope}, %{})
  end
end
