defmodule Otel.SDK.Config.SelectorTest do
  use ExUnit.Case, async: true

  describe "trace_exporter/1" do
    test "shortcut atoms map to project modules" do
      assert Otel.SDK.Config.Selector.trace_exporter(:otel_otlp) ==
               {Otel.OTLP.TraceExporter.HTTP, %{}}

      assert Otel.SDK.Config.Selector.trace_exporter(:console) ==
               {Otel.SDK.Trace.SpanExporter.Console, %{}}
    end

    test ":none stays :none" do
      assert Otel.SDK.Config.Selector.trace_exporter(:none) == :none
    end

    test "module atom is normalized to {Module, %{}}" do
      assert Otel.SDK.Config.Selector.trace_exporter(MyApp.Custom) ==
               {MyApp.Custom, %{}}
    end

    test "{module, config} tuple passes through" do
      assert Otel.SDK.Config.Selector.trace_exporter({MyApp.Custom, %{key: 1}}) ==
               {MyApp.Custom, %{key: 1}}
    end
  end

  describe "metrics_exporter/1" do
    test "shortcut atoms" do
      assert Otel.SDK.Config.Selector.metrics_exporter(:otel_otlp) ==
               {Otel.OTLP.MetricsExporter.HTTP, %{}}

      assert Otel.SDK.Config.Selector.metrics_exporter(:console) ==
               {Otel.SDK.Metrics.MetricExporter.Console, %{}}

      assert Otel.SDK.Config.Selector.metrics_exporter(:none) == :none
    end

    test "{module, config} passthrough" do
      assert Otel.SDK.Config.Selector.metrics_exporter({MyApp.Reader, %{x: 1}}) ==
               {MyApp.Reader, %{x: 1}}
    end
  end

  describe "logs_exporter/1" do
    test "shortcut atoms" do
      assert Otel.SDK.Config.Selector.logs_exporter(:otel_otlp) ==
               {Otel.OTLP.LogsExporter.HTTP, %{}}

      assert Otel.SDK.Config.Selector.logs_exporter(:console) ==
               {Otel.SDK.Logs.LogRecordExporter.Console, %{}}

      assert Otel.SDK.Config.Selector.logs_exporter(:none) == :none
    end
  end

  describe "trace_processor/1" do
    test "shortcut atoms map to processor modules" do
      assert Otel.SDK.Config.Selector.trace_processor(:batch) ==
               Otel.SDK.Trace.SpanProcessor.Batch

      assert Otel.SDK.Config.Selector.trace_processor(:simple) ==
               Otel.SDK.Trace.SpanProcessor.Simple
    end

    test "module passthrough" do
      assert Otel.SDK.Config.Selector.trace_processor(MyApp.Processor) ==
               MyApp.Processor
    end
  end

  describe "logs_processor/1" do
    test "shortcut atoms" do
      assert Otel.SDK.Config.Selector.logs_processor(:batch) ==
               Otel.SDK.Logs.LogRecordProcessor.Batch

      assert Otel.SDK.Config.Selector.logs_processor(:simple) ==
               Otel.SDK.Logs.LogRecordProcessor.Simple
    end
  end

  describe "sampler/1" do
    test "spec L143 enum values" do
      assert Otel.SDK.Config.Selector.sampler(:always_on) ==
               {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}

      assert Otel.SDK.Config.Selector.sampler(:always_off) ==
               {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}
    end

    test "parentbased variants wrap a root sampler" do
      assert Otel.SDK.Config.Selector.sampler(:parentbased_always_on) ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}

      assert Otel.SDK.Config.Selector.sampler(:parentbased_always_off) ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}}}
    end

    test "traceidratio with explicit ratio" do
      assert Otel.SDK.Config.Selector.sampler({:traceidratio, 0.25}) ==
               {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.25}
    end

    test "bare :traceidratio defaults ratio to 1.0 (spec L147)" do
      assert Otel.SDK.Config.Selector.sampler(:traceidratio) ==
               {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 1.0}
    end

    test "parentbased_traceidratio with explicit ratio" do
      assert Otel.SDK.Config.Selector.sampler({:parentbased_traceidratio, 0.5}) ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.5}}}
    end

    test "bare :parentbased_traceidratio defaults ratio to 1.0" do
      assert Otel.SDK.Config.Selector.sampler(:parentbased_traceidratio) ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 1.0}}}
    end

    test "{module, opts} passthrough" do
      assert Otel.SDK.Config.Selector.sampler({MyApp.Sampler, %{rate: 10}}) ==
               {MyApp.Sampler, %{rate: 10}}
    end

    test "module-only normalizes to {Module, %{}}" do
      assert Otel.SDK.Config.Selector.sampler(MyApp.Sampler) ==
               {MyApp.Sampler, %{}}
    end
  end
end
