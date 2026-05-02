defmodule Otel.SDK.Config.SelectorTest do
  use ExUnit.Case, async: true

  # Each selector accepts (a) a shortcut atom from the spec enum
  # → resolves to the project's concrete module/tuple, (b) a bare
  # module → wraps it as `{Module, %{}}` (for exporters/samplers)
  # or returns the module verbatim (for processors/propagators),
  # (c) a `{module, opts}` tuple → passes through unchanged.

  describe "trace_exporter/1, metrics_exporter/1, logs_exporter/1" do
    test "every exporter selector follows the same shortcut → tuple → tuple-passthrough shape" do
      cases = [
        {&Otel.SDK.Config.Selector.trace_exporter/1, {Otel.OTLP.Trace.SpanExporter.HTTP, %{}},
         {Otel.SDK.Trace.SpanExporter.Console, %{}}},
        {&Otel.SDK.Config.Selector.metrics_exporter/1,
         {Otel.OTLP.Metrics.MetricExporter.HTTP, %{}},
         {Otel.SDK.Metrics.MetricExporter.Console, %{}}},
        {&Otel.SDK.Config.Selector.logs_exporter/1, {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{}},
         {Otel.SDK.Logs.LogRecordExporter.Console, %{}}}
      ]

      for {selector, otlp_pair, console_pair} <- cases do
        assert selector.(:otlp) == otlp_pair
        assert selector.(:console) == console_pair
        assert selector.(:none) == :none
        assert selector.(MyApp.Custom) == {MyApp.Custom, %{}}
        assert selector.({MyApp.Custom, %{x: 1}}) == {MyApp.Custom, %{x: 1}}
      end
    end
  end

  describe "propagator/1" do
    test "implemented atoms map to project modules; custom modules pass through" do
      assert Otel.SDK.Config.Selector.propagator(:tracecontext) ==
               Otel.API.Propagator.TextMap.TraceContext

      assert Otel.SDK.Config.Selector.propagator(:baggage) ==
               Otel.API.Propagator.TextMap.Baggage

      assert Otel.SDK.Config.Selector.propagator(:none) ==
               Otel.API.Propagator.TextMap.Noop

      assert Otel.SDK.Config.Selector.propagator(MyApp.CustomPropagator) ==
               MyApp.CustomPropagator
    end

    test "spec-known but unimplemented propagators raise ArgumentError" do
      for unimpl <- [:b3, :b3multi, :jaeger, :xray, :ottrace] do
        assert_raise ArgumentError, ~r/not implemented in this SDK/, fn ->
          Otel.SDK.Config.Selector.propagator(unimpl)
        end
      end
    end
  end
end
