defmodule Otel.SDK.Trace.IdGenerator.DefaultTest do
  use ExUnit.Case, async: true

  @trace_id_max Bitwise.bsl(2, 127) - 1
  @span_id_max Bitwise.bsl(2, 63) - 1

  describe "generate_trace_id/0" do
    test "returns a positive integer" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_trace_id()
      assert is_integer(id)
      assert id > 0
    end

    test "returns value within 128-bit range" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_trace_id()
      assert id <= @trace_id_max
    end

    test "returns different values on subsequent calls" do
      ids = for _ <- 1..100, do: Otel.SDK.Trace.IdGenerator.Default.generate_trace_id()
      unique = Enum.uniq(ids)
      assert length(unique) > 1
    end
  end

  describe "generate_span_id/0" do
    test "returns a positive integer" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_span_id()
      assert is_integer(id)
      assert id > 0
    end

    test "returns value within 64-bit range" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_span_id()
      assert id <= @span_id_max
    end

    test "returns different values on subsequent calls" do
      ids = for _ <- 1..100, do: Otel.SDK.Trace.IdGenerator.Default.generate_span_id()
      unique = Enum.uniq(ids)
      assert length(unique) > 1
    end
  end
end
