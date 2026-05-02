defmodule Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucketTest do
  use ExUnit.Case, async: true

  @boundaries [10, 50, 100]
  @ctx %{}

  defp new_state,
    do: Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.new(%{boundaries: @boundaries})

  defp offer(state, value),
    do:
      Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.offer(
        state,
        value,
        1000,
        %{},
        @ctx
      )

  test "new/1 stores the boundaries" do
    assert new_state().boundaries == @boundaries
  end

  describe "offer/5 — at most one exemplar per bucket (boundaries+1 buckets total)" do
    test "different buckets keep separate exemplars" do
      state =
        new_state()
        |> offer(5)
        |> offer(25)
        |> offer(75)
        |> offer(200)

      assert map_size(state.exemplars) == 4
    end

    test "same bucket overwrites — newest exemplar wins" do
      state = new_state() |> offer(5) |> offer(8)

      assert map_size(state.exemplars) == 1
      assert state.exemplars[0].value == 8
    end

    test "many measurements never exceed boundaries+1 exemplars" do
      state = Enum.reduce(1..20, new_state(), &offer(&2, &1))
      assert map_size(state.exemplars) <= length(@boundaries) + 1
    end
  end

  describe "collect/1" do
    test "returns the offered exemplars and clears the reservoir" do
      state = new_state() |> offer(5) |> offer(75)

      {exemplars, new_state} =
        Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.collect(state)

      assert length(exemplars) == 2
      assert new_state.exemplars == %{}
    end

    test "empty reservoir → []" do
      assert {[], _} =
               Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket.collect(new_state())
    end
  end
end
