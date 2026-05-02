defmodule Otel.SDK.ConfigTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  @env_vars ~w(
    OTEL_SDK_DISABLED
    OTEL_TRACES_EXPORTER OTEL_METRICS_EXPORTER OTEL_LOGS_EXPORTER
    OTEL_TRACES_SAMPLER OTEL_TRACES_SAMPLER_ARG
    OTEL_BSP_SCHEDULE_DELAY OTEL_BSP_EXPORT_TIMEOUT
    OTEL_BSP_MAX_QUEUE_SIZE OTEL_BSP_MAX_EXPORT_BATCH_SIZE
    OTEL_BLRP_SCHEDULE_DELAY OTEL_BLRP_EXPORT_TIMEOUT
    OTEL_BLRP_MAX_QUEUE_SIZE OTEL_BLRP_MAX_EXPORT_BATCH_SIZE
    OTEL_METRIC_EXPORT_INTERVAL OTEL_METRIC_EXPORT_TIMEOUT
    OTEL_METRICS_EXEMPLAR_FILTER
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
    test "defaults: Batch(OTLP HTTP) + SpanLimits + Default IdGenerator" do
      config = Otel.SDK.Config.trace()

      assert [
               {Otel.SDK.Trace.SpanProcessor.Batch,
                %{exporter: {Otel.OTLP.Trace.SpanExporter.HTTP, %{}}}}
             ] = config.processors

      assert %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 128} = config.span_limits
      assert config.id_generator == Otel.SDK.Trace.IdGenerator.Default
    end

    test "Application env: exporter / processor selectors swap underlying module" do
      Application.put_env(:otel, :trace, exporter: :console)

      assert [{_, %{exporter: {Otel.SDK.Trace.SpanExporter.Console, %{}}}}] =
               Otel.SDK.Config.trace().processors

      Application.put_env(:otel, :trace, processor: :simple, exporter: :console)
      assert [{Otel.SDK.Trace.SpanProcessor.Simple, _}] = Otel.SDK.Config.trace().processors

      Application.put_env(:otel, :trace, exporter: :none)
      assert Otel.SDK.Config.trace().processors == []
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

    test "OTEL_TRACES_EXPORTER + OTEL_BSP_* knobs flow into Batch" do
      System.put_env("OTEL_TRACES_EXPORTER", "console")

      assert [{_, %{exporter: {Otel.SDK.Trace.SpanExporter.Console, %{}}}}] =
               Otel.SDK.Config.trace().processors

      System.put_env("OTEL_TRACES_EXPORTER", "none")
      assert Otel.SDK.Config.trace().processors == []

      System.delete_env("OTEL_TRACES_EXPORTER")
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

    # Spec sdk-environment-variables.md L389-L395.
    test "OTEL_SPAN_*_LIMIT overrides OTEL_ATTRIBUTE_*_LIMIT global fallback" do
      System.put_env("OTEL_ATTRIBUTE_COUNT_LIMIT", "32")
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 32

      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 64

      System.put_env("OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", "200")
      assert Otel.SDK.Config.trace().span_limits.attribute_value_length_limit == 200
    end

    test "Application env wins over OS env" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      Application.put_env(:otel, :trace, span_limits: %{attribute_count_limit: 256})
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 256
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
      System.put_env("OTEL_METRICS_EXPORTER", "none")
      assert Otel.SDK.Config.metrics().readers == []

      System.delete_env("OTEL_METRICS_EXPORTER")
      System.put_env("OTEL_METRIC_EXPORT_INTERVAL", "5000")
      [{_, config}] = Otel.SDK.Config.metrics().readers
      assert config.export_interval_ms == 5000

      System.put_env("OTEL_METRICS_EXEMPLAR_FILTER", "always_on")
      assert Otel.SDK.Config.metrics().exemplar_filter == :always_on

      Application.put_env(:otel, :metrics, readers: [{MyApp.Reader, %{}}])
      assert Otel.SDK.Config.metrics().readers == [{MyApp.Reader, %{}}]
    end
  end

  describe "logs/0" do
    test "defaults: Batch(OTLP HTTP) + LogRecordLimits" do
      [{Otel.SDK.Logs.LogRecordProcessor.Batch, config}] = Otel.SDK.Config.logs().processors

      assert config.exporter == {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{}}
      assert config.scheduled_delay_ms == 1_000

      assert %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 128} =
               Otel.SDK.Config.logs().log_record_limits
    end

    test "OTEL_LOGS_EXPORTER (console / none) + OTEL_BLRP_* + LOGRECORD/ATTRIBUTE fallbacks" do
      System.put_env("OTEL_LOGS_EXPORTER", "console")

      assert [{_, %{exporter: {Otel.SDK.Logs.LogRecordExporter.Console, %{}}}}] =
               Otel.SDK.Config.logs().processors

      System.put_env("OTEL_LOGS_EXPORTER", "none")
      assert Otel.SDK.Config.logs().processors == []

      System.delete_env("OTEL_LOGS_EXPORTER")
      System.put_env("OTEL_BLRP_SCHEDULE_DELAY", "200")
      System.put_env("OTEL_BLRP_MAX_QUEUE_SIZE", "100")
      [{_, config}] = Otel.SDK.Config.logs().processors
      assert config.scheduled_delay_ms == 200
      assert config.max_queue_size == 100

      System.put_env("OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT", "16")
      assert Otel.SDK.Config.logs().log_record_limits.attribute_count_limit == 16

      System.put_env("OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", "200")
      assert Otel.SDK.Config.logs().log_record_limits.attribute_value_length_limit == 200
    end
  end

  describe "propagator/0" do
    test "default: Composite of TraceContext + Baggage" do
      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.SDK.Config.propagator()
    end

    test "Application env :propagators — single, :none, list with :none, empty list" do
      Application.put_env(:otel, :propagators, [:tracecontext])
      assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.TraceContext

      Application.put_env(:otel, :propagators, [:none])
      assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.Noop

      Application.put_env(:otel, :propagators, [:tracecontext, :none])
      assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.Noop

      Application.put_env(:otel, :propagators, [])
      assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.Noop
    end

    test "Application env wins over OTEL_PROPAGATORS" do
      System.put_env("OTEL_PROPAGATORS", "tracecontext")
      Application.put_env(:otel, :propagators, [:baggage])
      assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.Baggage
    end

    # Spec api-propagators.md L107-L118.
    test "OTEL_PROPAGATORS — comma list / dedup / single / :none / empty / unknown / b3 raises" do
      System.put_env("OTEL_PROPAGATORS", "tracecontext,baggage")

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.SDK.Config.propagator()

      System.put_env("OTEL_PROPAGATORS", "tracecontext,baggage,tracecontext")

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.SDK.Config.propagator()

      System.put_env("OTEL_PROPAGATORS", "baggage")
      assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.Baggage

      System.put_env("OTEL_PROPAGATORS", "none")
      assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.Noop

      System.put_env("OTEL_PROPAGATORS", "")
      assert {Otel.API.Propagator.TextMap.Composite, _} = Otel.SDK.Config.propagator()

      log =
        capture_log(fn ->
          System.put_env("OTEL_PROPAGATORS", "tracecontext,mycustom")
          assert Otel.SDK.Config.propagator() == Otel.API.Propagator.TextMap.TraceContext
        end)

      assert log =~ "unknown name"
      assert log =~ "mycustom"

      System.put_env("OTEL_PROPAGATORS", "b3")

      assert_raise ArgumentError, ~r/not implemented in this SDK/, fn ->
        Otel.SDK.Config.propagator()
      end
    end
  end
end
