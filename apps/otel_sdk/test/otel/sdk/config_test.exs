defmodule Otel.SDK.ConfigTest do
  # async: false because env vars + Application env are global state.
  use ExUnit.Case, async: false

  @env_vars [
    "OTEL_SDK_DISABLED",
    "OTEL_TRACES_EXPORTER",
    "OTEL_METRICS_EXPORTER",
    "OTEL_LOGS_EXPORTER",
    "OTEL_TRACES_SAMPLER",
    "OTEL_TRACES_SAMPLER_ARG",
    "OTEL_BSP_SCHEDULE_DELAY",
    "OTEL_BSP_EXPORT_TIMEOUT",
    "OTEL_BSP_MAX_QUEUE_SIZE",
    "OTEL_BSP_MAX_EXPORT_BATCH_SIZE",
    "OTEL_BLRP_SCHEDULE_DELAY",
    "OTEL_BLRP_EXPORT_TIMEOUT",
    "OTEL_BLRP_MAX_QUEUE_SIZE",
    "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE",
    "OTEL_METRIC_EXPORT_INTERVAL",
    "OTEL_METRIC_EXPORT_TIMEOUT",
    "OTEL_METRICS_EXEMPLAR_FILTER",
    "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT",
    "OTEL_SPAN_EVENT_COUNT_LIMIT",
    "OTEL_SPAN_LINK_COUNT_LIMIT",
    "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT",
    "OTEL_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT"
  ]

  setup do
    on_exit(fn ->
      Enum.each(@env_vars, &System.delete_env/1)
      Application.delete_env(:otel_sdk, :trace)
      Application.delete_env(:otel_sdk, :metrics)
      Application.delete_env(:otel_sdk, :logs)
    end)

    :ok
  end

  describe "disabled?/0" do
    test "false by default" do
      assert Otel.SDK.Config.disabled?() == false
    end

    test "true when OTEL_SDK_DISABLED=true" do
      System.put_env("OTEL_SDK_DISABLED", "true")
      assert Otel.SDK.Config.disabled?() == true
    end

    test "false when OTEL_SDK_DISABLED=false" do
      System.put_env("OTEL_SDK_DISABLED", "false")
      assert Otel.SDK.Config.disabled?() == false
    end
  end

  describe "trace/0 — defaults" do
    test "returns parentbased_always_on sampler + batch processor + otlp exporter" do
      config = Otel.SDK.Config.trace()

      assert {Otel.SDK.Trace.Sampler.ParentBased, _} = config.sampler

      assert [
               {Otel.SDK.Trace.SpanProcessor.Batch,
                %{exporter: {Otel.OTLP.Trace.SpanExporter.HTTP, %{}}}}
             ] = config.processors

      assert %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 128} = config.span_limits
      assert config.id_generator == Otel.SDK.Trace.IdGenerator.Default
    end
  end

  describe "trace/0 — Application env layer" do
    test "explicit sampler wins over default" do
      Application.put_env(:otel_sdk, :trace, sampler: :always_off)
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = Otel.SDK.Config.trace().sampler
    end

    test "exporter :console swaps in console exporter" do
      Application.put_env(:otel_sdk, :trace, exporter: :console)

      [{Otel.SDK.Trace.SpanProcessor.Batch, %{exporter: exporter}}] =
        Otel.SDK.Config.trace().processors

      assert exporter == {Otel.SDK.Trace.SpanExporter.Console, %{}}
    end

    test "exporter :none disables processors entirely" do
      Application.put_env(:otel_sdk, :trace, exporter: :none)
      assert Otel.SDK.Config.trace().processors == []
    end

    test "processor :simple swaps the wrapper module" do
      Application.put_env(:otel_sdk, :trace, processor: :simple, exporter: :console)
      [{Otel.SDK.Trace.SpanProcessor.Simple, _}] = Otel.SDK.Config.trace().processors
    end

    test "explicit :processors list wins over the implicit single-processor build" do
      processors = [{MyApp.CustomProcessor, %{x: 1}}]
      Application.put_env(:otel_sdk, :trace, processors: processors)
      assert Otel.SDK.Config.trace().processors == processors
    end

    test "span_limits overrides merge into struct" do
      Application.put_env(:otel_sdk, :trace, span_limits: %{attribute_count_limit: 256})
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 256
      # untouched fields keep defaults
      assert Otel.SDK.Config.trace().span_limits.event_count_limit == 128
    end
  end

  describe "trace/0 — OS env layer" do
    test "OTEL_TRACES_SAMPLER=always_off" do
      System.put_env("OTEL_TRACES_SAMPLER", "always_off")
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, _} = Otel.SDK.Config.trace().sampler
    end

    test "OTEL_TRACES_SAMPLER=traceidratio + OTEL_TRACES_SAMPLER_ARG=0.25" do
      System.put_env("OTEL_TRACES_SAMPLER", "traceidratio")
      System.put_env("OTEL_TRACES_SAMPLER_ARG", "0.25")

      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.25} = Otel.SDK.Config.trace().sampler
    end

    test "OTEL_TRACES_SAMPLER=traceidratio with no arg defaults to 1.0" do
      System.put_env("OTEL_TRACES_SAMPLER", "traceidratio")
      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 1.0} = Otel.SDK.Config.trace().sampler
    end

    test "OTEL_TRACES_EXPORTER=console" do
      System.put_env("OTEL_TRACES_EXPORTER", "console")

      [{_, %{exporter: exporter}}] = Otel.SDK.Config.trace().processors
      assert exporter == {Otel.SDK.Trace.SpanExporter.Console, %{}}
    end

    test "OTEL_TRACES_EXPORTER=none disables processors" do
      System.put_env("OTEL_TRACES_EXPORTER", "none")
      assert Otel.SDK.Config.trace().processors == []
    end

    test "OTEL_BSP_* knobs flow into the Batch processor config" do
      System.put_env("OTEL_BSP_SCHEDULE_DELAY", "100")
      System.put_env("OTEL_BSP_EXPORT_TIMEOUT", "0")
      System.put_env("OTEL_BSP_MAX_QUEUE_SIZE", "999")
      System.put_env("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", "111")

      [{_, config}] = Otel.SDK.Config.trace().processors
      assert config.scheduled_delay_ms == 100
      assert config.export_timeout_ms == :infinity
      assert config.max_queue_size == 999
      assert config.max_export_batch_size == 111
    end

    test "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT overrides the default limit" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 64
    end

    test "OTEL_ATTRIBUTE_COUNT_LIMIT is the global fallback" do
      System.put_env("OTEL_ATTRIBUTE_COUNT_LIMIT", "32")
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 32
    end

    test "OTEL_SPAN_* takes precedence over OTEL_ATTRIBUTE_*" do
      System.put_env("OTEL_ATTRIBUTE_COUNT_LIMIT", "32")
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 64
    end
  end

  describe "trace/0 — precedence" do
    test "Application env wins over OS env" do
      System.put_env("OTEL_TRACES_SAMPLER", "always_off")
      Application.put_env(:otel_sdk, :trace, sampler: :always_on)

      assert {Otel.SDK.Trace.Sampler.AlwaysOn, _} = Otel.SDK.Config.trace().sampler
    end

    test "OS env wins over default" do
      System.put_env("OTEL_TRACES_EXPORTER", "console")

      [{_, %{exporter: exporter}}] = Otel.SDK.Config.trace().processors
      assert exporter == {Otel.SDK.Trace.SpanExporter.Console, %{}}
    end

    test "App env span_limits override OS env span_limits" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      Application.put_env(:otel_sdk, :trace, span_limits: %{attribute_count_limit: 256})

      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 256
    end
  end

  describe "metrics/0" do
    test "defaults: MetricReader.PeriodicExporting + OTLP" do
      [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, reader_config}] =
        Otel.SDK.Config.metrics().readers

      assert reader_config.exporter == {Otel.OTLP.Metrics.MetricExporter.HTTP, %{}}
      assert reader_config.export_interval_ms == 60_000
      assert reader_config.export_timeout_ms == 30_000
      assert Otel.SDK.Config.metrics().exemplar_filter == :trace_based
    end

    test "OTEL_METRICS_EXPORTER=none yields no readers" do
      System.put_env("OTEL_METRICS_EXPORTER", "none")
      assert Otel.SDK.Config.metrics().readers == []
    end

    test "OTEL_METRIC_EXPORT_INTERVAL flows into reader config" do
      System.put_env("OTEL_METRIC_EXPORT_INTERVAL", "5000")

      [{_, config}] = Otel.SDK.Config.metrics().readers
      assert config.export_interval_ms == 5000
    end

    test "OTEL_METRICS_EXEMPLAR_FILTER override" do
      System.put_env("OTEL_METRICS_EXEMPLAR_FILTER", "always_on")
      assert Otel.SDK.Config.metrics().exemplar_filter == :always_on
    end

    test "Application env :readers wins over implicit build" do
      Application.put_env(:otel_sdk, :metrics, readers: [{MyApp.Reader, %{}}])
      assert Otel.SDK.Config.metrics().readers == [{MyApp.Reader, %{}}]
    end
  end

  describe "logs/0" do
    test "defaults: Batch processor + OTLP" do
      [{Otel.SDK.Logs.LogRecordProcessor.Batch, config}] =
        Otel.SDK.Config.logs().processors

      assert config.exporter == {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{}}
      assert config.scheduled_delay_ms == 1_000

      assert %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 128} =
               Otel.SDK.Config.logs().log_record_limits
    end

    test "OTEL_LOGS_EXPORTER=console" do
      System.put_env("OTEL_LOGS_EXPORTER", "console")

      [{_, %{exporter: exporter}}] = Otel.SDK.Config.logs().processors
      assert exporter == {Otel.SDK.Logs.LogRecordExporter.Console, %{}}
    end

    test "OTEL_LOGS_EXPORTER=none yields no processors" do
      System.put_env("OTEL_LOGS_EXPORTER", "none")
      assert Otel.SDK.Config.logs().processors == []
    end

    test "OTEL_BLRP_* knobs flow into the Batch config" do
      System.put_env("OTEL_BLRP_SCHEDULE_DELAY", "200")
      System.put_env("OTEL_BLRP_MAX_QUEUE_SIZE", "100")

      [{_, config}] = Otel.SDK.Config.logs().processors
      assert config.scheduled_delay_ms == 200
      assert config.max_queue_size == 100
    end

    test "OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT overrides the default" do
      System.put_env("OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT", "16")
      assert Otel.SDK.Config.logs().log_record_limits.attribute_count_limit == 16
    end
  end
end
