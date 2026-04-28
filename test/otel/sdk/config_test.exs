defmodule Otel.SDK.ConfigTest do
  # async: false because env vars + Application env are global state.
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
      Application.delete_env(:otel, :trace)
      Application.delete_env(:otel, :metrics)
      Application.delete_env(:otel, :logs)
      Application.delete_env(:otel, :propagators)
    end)

    :ok
  end

  describe "disabled?/0" do
    test "OTEL_SDK_DISABLED — false by default; true only when set to \"true\"" do
      assert Otel.SDK.Config.disabled?() == false

      System.put_env("OTEL_SDK_DISABLED", "false")
      assert Otel.SDK.Config.disabled?() == false

      System.put_env("OTEL_SDK_DISABLED", "true")
      assert Otel.SDK.Config.disabled?() == true
    end
  end

  describe "trace/0 — defaults" do
    test "ParentBased sampler + Batch processor + OTLP exporter + default SpanLimits + Default IdGenerator" do
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
    test "sampler / exporter / processor selectors swap the underlying module" do
      Application.put_env(:otel, :trace, sampler: :always_off)
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = Otel.SDK.Config.trace().sampler

      Application.put_env(:otel, :trace, exporter: :console)

      assert [
               {Otel.SDK.Trace.SpanProcessor.Batch,
                %{exporter: {Otel.SDK.Trace.SpanExporter.Console, %{}}}}
             ] =
               Otel.SDK.Config.trace().processors

      Application.put_env(:otel, :trace, processor: :simple, exporter: :console)
      assert [{Otel.SDK.Trace.SpanProcessor.Simple, _}] = Otel.SDK.Config.trace().processors

      Application.put_env(:otel, :trace, exporter: :none)
      assert Otel.SDK.Config.trace().processors == []
    end

    test "explicit :processors list bypasses the implicit single-processor build" do
      processors = [{MyApp.CustomProcessor, %{x: 1}}]
      Application.put_env(:otel, :trace, processors: processors)
      assert Otel.SDK.Config.trace().processors == processors
    end

    test "span_limits accepts both map and keyword forms; merges into struct (untouched fields keep defaults)" do
      Application.put_env(:otel, :trace, span_limits: %{attribute_count_limit: 256})
      limits = Otel.SDK.Config.trace().span_limits
      assert limits.attribute_count_limit == 256
      assert limits.event_count_limit == 128

      Application.put_env(:otel, :trace, span_limits: [attribute_count_limit: 64])
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 64
    end
  end

  describe "trace/0 — OS env layer" do
    test "OTEL_TRACES_SAMPLER selects sampler module; SAMPLER_ARG drives traceidratio probability" do
      System.put_env("OTEL_TRACES_SAMPLER", "always_off")
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, _} = Otel.SDK.Config.trace().sampler

      System.put_env("OTEL_TRACES_SAMPLER", "traceidratio")
      System.put_env("OTEL_TRACES_SAMPLER_ARG", "0.25")
      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.25} = Otel.SDK.Config.trace().sampler

      # Missing / unparseable / out-of-range arg → fallback to 1.0.
      for arg <- [nil, "bad-ratio", "1.5"] do
        if arg,
          do: System.put_env("OTEL_TRACES_SAMPLER_ARG", arg),
          else: System.delete_env("OTEL_TRACES_SAMPLER_ARG")

        assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 1.0} =
                 Otel.SDK.Config.trace().sampler
      end
    end

    test "OTEL_TRACES_EXPORTER selects span exporter (:none disables processors)" do
      System.put_env("OTEL_TRACES_EXPORTER", "console")

      assert [{_, %{exporter: {Otel.SDK.Trace.SpanExporter.Console, %{}}}}] =
               Otel.SDK.Config.trace().processors

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

    # Spec sdk-environment-variables.md L389-L395: OTEL_SPAN_*
    # specific limit overrides the OTEL_ATTRIBUTE_* global fallback.
    test "OTEL_*_LIMIT env vars: SPAN-specific overrides the ATTRIBUTE-* global fallback" do
      System.put_env("OTEL_ATTRIBUTE_COUNT_LIMIT", "32")
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 32

      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 64

      System.put_env("OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", "200")
      assert Otel.SDK.Config.trace().span_limits.attribute_value_length_limit == 200
    end
  end

  describe "trace/0 — precedence (Application env > OS env > defaults)" do
    test "Application env wins over OS env" do
      System.put_env("OTEL_TRACES_SAMPLER", "always_off")
      Application.put_env(:otel, :trace, sampler: :always_on)
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, _} = Otel.SDK.Config.trace().sampler

      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      Application.put_env(:otel, :trace, span_limits: %{attribute_count_limit: 256})
      assert Otel.SDK.Config.trace().span_limits.attribute_count_limit == 256
    end
  end

  describe "metrics/0" do
    test "defaults: PeriodicExporting reader + OTLP exporter + :trace_based exemplar filter" do
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
    test "defaults: Batch processor + OTLP exporter + default LogRecordLimits" do
      [{Otel.SDK.Logs.LogRecordProcessor.Batch, config}] = Otel.SDK.Config.logs().processors

      assert config.exporter == {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{}}
      assert config.scheduled_delay_ms == 1_000

      assert %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 128} =
               Otel.SDK.Config.logs().log_record_limits
    end

    test "OTEL_LOGS_EXPORTER (console / none) + OTEL_BLRP_* + OTEL_LOGRECORD_* + OTEL_ATTRIBUTE_* fallbacks" do
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
    test "default — Composite of TraceContext + Baggage (spec L116)" do
      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.SDK.Config.propagator()
    end

    test "Application env :propagators — single, :none, list-with-:none, empty list" do
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

    # Spec api-propagators.md L107-L118 — accepts comma-separated
    # names, dedupes, falls back to default on empty, warns on
    # unknown values.
    test "OTEL_PROPAGATORS — comma list / deduped / single / :none / empty / unknown" do
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
    end

    test "spec-known but unimplemented (b3) propagates the Selector raise" do
      System.put_env("OTEL_PROPAGATORS", "b3")

      assert_raise ArgumentError, ~r/not implemented in this SDK/, fn ->
        Otel.SDK.Config.propagator()
      end
    end
  end
end
