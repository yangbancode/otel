defmodule Otel.SDK.Trace.SpanExporterTest.TestExporter do
  @behaviour Otel.SDK.Trace.SpanExporter

  @spec init(config :: term()) :: {:ok, Otel.SDK.Trace.SpanExporter.state()} | :ignore
  @impl true
  def init(config), do: {:ok, config}

  @spec export(
          spans :: [Otel.SDK.Trace.Span.t()],
          resource :: map(),
          state :: Otel.SDK.Trace.SpanExporter.state()
        ) :: :ok | :error
  @impl true
  def export(spans, _resource, %{test_pid: pid}) do
    send(pid, {:exported, length(spans)})
    :ok
  end

  @spec shutdown(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def shutdown(_state), do: :ok
end

defmodule Otel.SDK.Trace.SpanExporterTest do
  use ExUnit.Case, async: true

  describe "behaviour" do
    test "TestExporter implements all callbacks" do
      assert {:ok, state} =
               Otel.SDK.Trace.SpanExporterTest.TestExporter.init(%{test_pid: self()})

      span = %Otel.SDK.Trace.Span{
        trace_id: 1,
        span_id: 1,
        name: "test"
      }

      assert :ok =
               Otel.SDK.Trace.SpanExporterTest.TestExporter.export([span], %{}, state)

      assert_receive {:exported, 1}

      assert :ok = Otel.SDK.Trace.SpanExporterTest.TestExporter.shutdown(state)
    end
  end
end
