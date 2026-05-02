defmodule Otel.SDK.ConfigTest do
  use ExUnit.Case, async: false

  @env_vars ~w(
    OTEL_SDK_DISABLED
    OTEL_TRACES_EXPORTER OTEL_METRICS_EXPORTER OTEL_LOGS_EXPORTER
    OTEL_TRACES_SAMPLER OTEL_TRACES_SAMPLER_ARG
    OTEL_METRIC_EXPORT_INTERVAL OTEL_METRIC_EXPORT_TIMEOUT
    OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT
    OTEL_SPAN_EVENT_COUNT_LIMIT OTEL_SPAN_LINK_COUNT_LIMIT
    OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT OTEL_LINK_ATTRIBUTE_COUNT_LIMIT
    OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT
    OTEL_ATTRIBUTE_COUNT_LIMIT OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT
    OTEL_PROPAGATORS
  )

  setup do
    on_exit(fn ->
      Enum.each(@env_vars, &System.delete_env/1)
      for k <- [:trace, :metrics, :logs, :propagators], do: Application.delete_env(:otel, k)
    end)

    :ok
  end

  describe "disabled?/0" do
    test "default false; env var \"true\" → true" do
      assert Otel.SDK.Config.disabled?() == false

      System.put_env("OTEL_SDK_DISABLED", "false")
      assert Otel.SDK.Config.disabled?() == false

      System.put_env("OTEL_SDK_DISABLED", "true")
      assert Otel.SDK.Config.disabled?() == true
    end
  end

  describe "trace/0" do
    test "defaults: Batch(OTLP HTTP) + SpanLimits" do
      config = Otel.SDK.Config.trace()

      assert [
               {Otel.SDK.Trace.SpanProcessor,
                %{exporter: {Otel.OTLP.Trace.SpanExporter.HTTP, %{}}}}
             ] = config.processors

      assert %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 128} = config.span_limits
      refute Map.has_key?(config, :id_generator)
    end

    test "Application env: explicit :processors list bypasses implicit build" do
      processors = [{MyApp.CustomProcessor, %{x: 1}}]
      Application.put_env(:otel, :trace, processors: processors)
      assert Otel.SDK.Config.trace().processors == processors
    end

    test "span_limits accepts map and keyword forms; untouched fields keep defaults" do
      Application.put_env(:otel, :trace, span_limits: %{attribute_count_limit: 256})
      limits = Otel.SDK.Config.trace().span_limits
      assert limits.attribute_count_limit == 256
      assert limits.event_count_limit == 128

      Application.put_env(:otel, :trace, span_limits: [attribute_count_limit: 64])
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 64
    end
  end

  describe "metrics/0" do
    test "defaults: PeriodicExporting(OTLP HTTP) + :trace_based exemplar" do
      [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, reader}] =
        Otel.SDK.Config.metrics().readers

      assert reader.exporter == {Otel.OTLP.Metrics.MetricExporter.HTTP, %{}}
      assert reader.export_interval_ms == 60_000
      assert reader.export_timeout_ms == 30_000
      assert Otel.SDK.Config.metrics().exemplar_filter == :trace_based
    end

    test "env-var overrides + Application :readers shortcut" do
      System.put_env("OTEL_METRIC_EXPORT_INTERVAL", "5000")
      [{_, config}] = Otel.SDK.Config.metrics().readers
      assert config.export_interval_ms == 5000

      Application.put_env(:otel, :metrics, readers: [{MyApp.Reader, %{}}])
      assert Otel.SDK.Config.metrics().readers == [{MyApp.Reader, %{}}]
    end

    test ":exemplar_filter Application env override (advanced; for tests)" do
      Application.put_env(:otel, :metrics, exemplar_filter: :always_on)
      assert Otel.SDK.Config.metrics().exemplar_filter == :always_on
    end
  end

  describe "logs/0" do
    test "defaults: Batch(OTLP HTTP) + LogRecordLimits" do
      [{Otel.SDK.Logs.LogRecordProcessor, config}] = Otel.SDK.Config.logs().processors

      assert config.exporter == {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{}}

      assert %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 128} =
               Otel.SDK.Config.logs().log_record_limits
    end
  end

  describe "propagator/0" do
    test "hardcoded: Composite of TraceContext + Baggage" do
      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.SDK.Config.propagator()
    end

    test "ignores Application env :propagators (no longer read)" do
      Application.put_env(:otel, :propagators, [:tracecontext])

      assert {Otel.API.Propagator.TextMap.Composite, _} = Otel.SDK.Config.propagator()
    end

    test "ignores OTEL_PROPAGATORS env var (no longer read)" do
      System.put_env("OTEL_PROPAGATORS", "baggage")

      assert {Otel.API.Propagator.TextMap.Composite, _} = Otel.SDK.Config.propagator()
    end
  end
end
