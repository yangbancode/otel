defmodule Otel.SDK.Trace.IdGenerator.DefaultTest do
  use ExUnit.Case, async: true

  @trace_id_max Bitwise.bsl(2, 127) - 1
  @span_id_max Bitwise.bsl(2, 63) - 1

  test "generate_trace_id/0 returns a positive integer in [1, 2^128 - 1] with non-trivial entropy" do
    ids = for _ <- 1..100, do: Otel.SDK.Trace.IdGenerator.Default.generate_trace_id()

    for id <- ids do
      assert is_integer(id)
      assert id > 0
      assert id <= @trace_id_max
    end

    assert length(Enum.uniq(ids)) > 1
  end

  test "generate_span_id/0 returns a positive integer in [1, 2^64 - 1] with non-trivial entropy" do
    ids = for _ <- 1..100, do: Otel.SDK.Trace.IdGenerator.Default.generate_span_id()

    for id <- ids do
      assert is_integer(id)
      assert id > 0
      assert id <= @span_id_max
    end

    assert length(Enum.uniq(ids)) > 1
  end
end
