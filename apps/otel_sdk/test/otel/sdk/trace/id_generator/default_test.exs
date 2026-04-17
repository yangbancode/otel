defmodule Otel.SDK.Trace.IdGenerator.DefaultTest do
  use ExUnit.Case, async: true

  describe "generate_trace_id/0" do
    test "returns a valid TraceId struct" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_trace_id()
      assert %Otel.API.Trace.TraceId{} = id
      assert Otel.API.Trace.TraceId.valid?(id)
    end

    test "returns 16-byte binary representation" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_trace_id()
      bytes = Otel.API.Trace.TraceId.to_bytes(id)
      assert byte_size(bytes) == 16
    end

    test "returns different values on subsequent calls" do
      ids = for _ <- 1..100, do: Otel.SDK.Trace.IdGenerator.Default.generate_trace_id()
      unique = Enum.uniq(ids)
      assert length(unique) > 1
    end
  end

  describe "generate_span_id/0" do
    test "returns a valid SpanId struct" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_span_id()
      assert %Otel.API.Trace.SpanId{} = id
      assert Otel.API.Trace.SpanId.valid?(id)
    end

    test "returns 8-byte binary representation" do
      id = Otel.SDK.Trace.IdGenerator.Default.generate_span_id()
      bytes = Otel.API.Trace.SpanId.to_bytes(id)
      assert byte_size(bytes) == 8
    end

    test "returns different values on subsequent calls" do
      ids = for _ <- 1..100, do: Otel.SDK.Trace.IdGenerator.Default.generate_span_id()
      unique = Enum.uniq(ids)
      assert length(unique) > 1
    end
  end
end
