defmodule Otel.SDK.Trace.SpanExporterTest do
  use ExUnit.Case, async: true

  defmodule TestExporter do
    @moduledoc false
    @behaviour Otel.SDK.Trace.SpanExporter

    @impl true
    def init(config), do: {:ok, config}
    @impl true
    def export(spans, _resource, %{test_pid: pid}) do
      send(pid, {:exported, length(spans)})
      :ok
    end

    @impl true
    def shutdown(_state), do: :ok
    @impl true
    def force_flush(_state), do: :ok
  end

  # Smoke-test the behaviour contract: every callback is callable
  # and returns the documented success shape. Concrete exporters
  # (Console, OTLP HTTP) carry their own behaviour-driven tests.
  test "init/1 + export/3 + shutdown/1 + force_flush/1 round-trip" do
    assert {:ok, state} = TestExporter.init(%{test_pid: self()})

    span = %Otel.SDK.Trace.Span{trace_id: 1, span_id: 1, name: "test"}
    assert :ok = TestExporter.export([span], %{}, state)
    assert_receive {:exported, 1}

    assert :ok = TestExporter.shutdown(state)
    assert :ok = TestExporter.force_flush(state)
  end
end
