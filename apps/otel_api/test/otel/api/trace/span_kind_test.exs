defmodule Otel.API.Trace.SpanKindTest do
  use ExUnit.Case, async: true

  describe "type" do
    test "all span kinds are valid atoms" do
      kinds = [:internal, :server, :client, :producer, :consumer]

      for kind <- kinds do
        assert is_atom(kind)
        assert kind in [:internal, :server, :client, :producer, :consumer]
      end
    end
  end

  # SpanKind is a type-only module. Dialyzer enforces the type
  # constraint. This test documents the valid values.
  test "module exists" do
    assert Code.ensure_loaded?(Otel.API.Trace.SpanKind)
  end
end
