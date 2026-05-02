defmodule Otel.Trace.IdGeneratorTest do
  use ExUnit.Case, async: true

  describe "generate_trace_id/0" do
    test "produces unique non-zero 128-bit integers" do
      ids = for _ <- 1..100, do: Otel.Trace.IdGenerator.generate_trace_id()

      assert length(Enum.uniq(ids)) == 100
      assert Enum.all?(ids, &(&1 > 0))
      assert Enum.all?(ids, &(&1 < Bitwise.bsl(1, 128)))
    end
  end

  describe "generate_span_id/0" do
    test "produces unique non-zero 64-bit integers" do
      ids = for _ <- 1..100, do: Otel.Trace.IdGenerator.generate_span_id()

      assert length(Enum.uniq(ids)) == 100
      assert Enum.all?(ids, &(&1 > 0))
      assert Enum.all?(ids, &(&1 < Bitwise.bsl(1, 64)))
    end
  end
end
