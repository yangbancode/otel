defmodule Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucketTest do
  use ExUnit.Case, async: true

  @boundaries [10, 50, 100]

  defp ctx, do: Otel.API.Ctx.new()

  describe "new/1" do
    test "stores boundaries" do
      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.new(%{boundaries: @boundaries})

      assert state.boundaries == @boundaries
    end
  end

  describe "offer/5" do
    test "stores exemplar in correct bucket" do
      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.new(%{boundaries: @boundaries})

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          5,
          1000,
          %{},
          ctx()
        )

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          25,
          1000,
          %{},
          ctx()
        )

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          75,
          1000,
          %{},
          ctx()
        )

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          200,
          1000,
          %{},
          ctx()
        )

      assert map_size(state.exemplars) == 4
    end

    test "replaces exemplar in same bucket" do
      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.new(%{boundaries: @boundaries})

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          5,
          1000,
          %{},
          ctx()
        )

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          8,
          2000,
          %{},
          ctx()
        )

      assert map_size(state.exemplars) == 1
      assert state.exemplars[0].value == 8
    end

    test "at most one exemplar per bucket" do
      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.new(%{boundaries: @boundaries})

      state =
        Enum.reduce(1..20, state, fn i, s ->
          Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(s, i, 1000, %{}, ctx())
        end)

      assert map_size(state.exemplars) <= length(@boundaries) + 1
    end
  end

  describe "collect/1" do
    test "returns exemplars and clears" do
      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.new(%{boundaries: @boundaries})

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          5,
          1000,
          %{},
          ctx()
        )

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
          state,
          75,
          1000,
          %{},
          ctx()
        )

      {exemplars, new_state} =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.collect(state)

      assert length(exemplars) == 2
      assert new_state.exemplars == %{}
    end

    test "empty reservoir returns empty" do
      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.new(%{boundaries: @boundaries})

      {exemplars, _} = Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.collect(state)
      assert exemplars == []
    end
  end
end
