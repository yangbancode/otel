defmodule Otel.Metrics.Exemplar.ReservoirTest do
  use ExUnit.Case, async: true

  defp reservoir_with_one_slot do
    {Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize,
     Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})}
  end

  defp sampled_ctx do
    Otel.Trace.set_current_span(
      Otel.Ctx.new(),
      Otel.Trace.SpanContext.new(%{trace_id: 1, span_id: 1, trace_flags: 1})
    )
  end

  describe "offer/5 — dispatch through the trace_based filter" do
    test "sampled context forwards to the reservoir; not-sampled context skips" do
      assert {Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize, %{count: 1}} =
               Otel.Metrics.Exemplar.Reservoir.offer(
                 reservoir_with_one_slot(),
                 42,
                 1000,
                 %{},
                 sampled_ctx()
               )

      assert {Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize, %{count: 0}} =
               Otel.Metrics.Exemplar.Reservoir.offer(
                 reservoir_with_one_slot(),
                 42,
                 1000,
                 %{},
                 %{}
               )
    end
  end

  describe "collect/1" do
    test "returns the offered exemplars and resets the reservoir state" do
      state =
        Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})
        |> Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(42, 1000, %{}, %{})

      assert {[exemplar], {_mod, %{count: 0}}} =
               Otel.Metrics.Exemplar.Reservoir.collect(
                 {Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize, state}
               )

      assert exemplar.value == 42
    end
  end
end
