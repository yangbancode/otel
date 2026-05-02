defmodule Otel.SDK.ConfigTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      for k <- [:trace, :metrics, :logs, :resource, :exporter],
          do: Application.delete_env(:otel, k)
    end)

    :ok
  end

  describe "resource/0" do
    test "no :resource set → SDK identity + service.name=\"unknown_service\"" do
      attrs = Otel.SDK.Config.resource().attributes
      assert attrs["telemetry.sdk.name"] == "otel"
      assert attrs["service.name"] == "unknown_service"
    end

    test ":resource map merges on top of SDK identity; user service.name wins" do
      Application.put_env(:otel, :resource, %{
        "service.name" => "my_app",
        "deployment.environment" => "prod"
      })

      attrs = Otel.SDK.Config.resource().attributes
      assert attrs["service.name"] == "my_app"
      assert attrs["deployment.environment"] == "prod"
      assert attrs["telemetry.sdk.name"] == "otel"
    end
  end

  describe "exporter/1" do
    test "no :exporter set → empty config map for each signal" do
      assert Otel.SDK.Config.exporter(:trace) == {Otel.Trace.SpanExporter, %{}}
      assert Otel.SDK.Config.exporter(:metrics) == {Otel.Metrics.MetricExporter, %{}}
      assert Otel.SDK.Config.exporter(:logs) == {Otel.Logs.LogRecordExporter, %{}}
    end

    test ":exporter map forwarded verbatim to all three signals" do
      Application.put_env(:otel, :exporter, %{
        endpoint: "https://collector:4318",
        headers: %{"x-api-key" => "secret"}
      })

      assert {Otel.Trace.SpanExporter, config} = Otel.SDK.Config.exporter(:trace)
      assert config.endpoint == "https://collector:4318"
      assert config.headers == %{"x-api-key" => "secret"}

      assert {Otel.Metrics.MetricExporter, ^config} = Otel.SDK.Config.exporter(:metrics)
      assert {Otel.Logs.LogRecordExporter, ^config} = Otel.SDK.Config.exporter(:logs)
    end
  end

  describe "trace/0" do
    test "defaults: Batch(OTLP HTTP) + SpanLimits + identity Resource" do
      config = Otel.SDK.Config.trace()

      assert [
               {Otel.Trace.SpanProcessor, %{exporter: {Otel.Trace.SpanExporter, %{}}}}
             ] = config.processors

      assert %Otel.Trace.SpanLimits{attribute_count_limit: 128} = config.span_limits
      assert config.resource.attributes["service.name"] == "unknown_service"
      refute Map.has_key?(config, :id_generator)
    end

    test "top-level :resource flows into trace pillar" do
      Application.put_env(:otel, :resource, %{"service.name" => "from_top"})
      assert Otel.SDK.Config.trace().resource.attributes["service.name"] == "from_top"
    end

    test "top-level :exporter flows into the default processor's exporter config" do
      Application.put_env(:otel, :exporter, %{endpoint: "https://collector:4318"})

      [{_, %{exporter: {Otel.Trace.SpanExporter, exp_config}}}] =
        Otel.SDK.Config.trace().processors

      assert exp_config.endpoint == "https://collector:4318"
    end
  end

  describe "metrics/0" do
    test "defaults: PeriodicExporting(OTLP HTTP) + :trace_based exemplar" do
      [{Otel.Metrics.MetricReader.PeriodicExporting, reader}] =
        Otel.SDK.Config.metrics().readers

      assert reader.exporter == {Otel.Metrics.MetricExporter, %{}}
      assert reader.export_interval_ms == 60_000
      assert reader.export_timeout_ms == 30_000
      assert Otel.SDK.Config.metrics().exemplar_filter == :trace_based
    end
  end

  describe "logs/0" do
    test "defaults: Batch(OTLP HTTP) + LogRecordLimits" do
      [{Otel.Logs.LogRecordProcessor, config}] = Otel.SDK.Config.logs().processors

      assert config.exporter == {Otel.Logs.LogRecordExporter, %{}}

      assert %Otel.Logs.LogRecordLimits{attribute_count_limit: 128} =
               Otel.SDK.Config.logs().log_record_limits
    end
  end
end
