defmodule Otel.Exporter.OTLP.EncoderTest do
  use ExUnit.Case, async: true

  @span %Otel.SDK.Trace.Span{
    trace_id: 0x0AF7651916CD43DD8448EB211C80319C,
    span_id: 0xB7AD6B7169203331,
    parent_span_id: nil,
    tracestate: %Otel.API.Trace.TraceState{},
    name: "test_span",
    kind: :server,
    start_time: 1_000_000_000,
    end_time: 2_000_000_000,
    attributes: %{"http.method" => "GET", "http.status_code" => 200},
    events: [
      %Otel.API.Trace.Event{
        name: "event1",
        timestamp: 1_500_000_000,
        attributes: %{"key" => "val"}
      }
    ],
    links: [],
    status: %Otel.API.Trace.Status{code: :ok},
    trace_flags: 1,
    is_recording: false,
    instrumentation_scope: %Otel.API.InstrumentationScope{
      name: "test_lib",
      version: "1.0.0"
    }
  }

  @resource Otel.SDK.Resource.create(%{
              "service.name" => "test-service",
              "telemetry.sdk.language" => "elixir"
            })

  describe "encode_traces/2" do
    test "produces valid protobuf binary" do
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([@span], @resource)
      assert is_binary(binary)
      assert byte_size(binary) > 0
    end

    test "binary can be decoded back" do
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([@span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      assert length(decoded.resource_spans) == 1
    end

    test "encodes resource attributes" do
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([@span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      resource_spans = hd(decoded.resource_spans)
      attrs = resource_spans.resource.attributes
      service_attr = Enum.find(attrs, &(&1.key == "service.name"))
      assert {:string_value, "test-service"} = service_attr.value.value
    end

    test "encodes span fields correctly" do
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([@span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      scope_spans = hd(hd(decoded.resource_spans).scope_spans)
      span = hd(scope_spans.spans)

      assert span.name == "test_span"
      assert span.kind == :SPAN_KIND_SERVER
      assert span.start_time_unix_nano == 1_000_000_000
      assert span.end_time_unix_nano == 2_000_000_000
      assert span.trace_id == <<0x0AF7651916CD43DD8448EB211C80319C::128>>
      assert span.span_id == <<0xB7AD6B7169203331::64>>
      assert span.parent_span_id == <<>>
    end

    test "encodes instrumentation scope" do
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([@span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      scope_spans = hd(hd(decoded.resource_spans).scope_spans)
      assert scope_spans.scope.name == "test_lib"
      assert scope_spans.scope.version == "1.0.0"
    end

    test "encodes events" do
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([@span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      event = hd(span.events)
      assert event.name == "event1"
      assert event.time_unix_nano == 1_500_000_000
    end

    test "encodes status ok" do
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([@span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert span.status.code == :STATUS_CODE_OK
    end

    test "encodes status error" do
      error_span = %{
        @span
        | status: %Otel.API.Trace.Status{code: :error, description: "something failed"}
      }

      binary = Otel.Exporter.OTLP.Encoder.encode_traces([error_span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert span.status.code == :STATUS_CODE_ERROR
      assert span.status.message == "something failed"
    end

    test "encodes unset status as no status" do
      unset_status_span = %{@span | status: %Otel.API.Trace.Status{code: :unset}}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([unset_status_span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert span.status == nil
    end

    test "encodes links" do
      linked_ctx = Otel.API.Trace.SpanContext.new(100, 200, 1)

      span_with_link = %{
        @span
        | links: [
            %Otel.API.Trace.Link{context: linked_ctx, attributes: %{"link.key" => "val"}}
          ]
      }

      binary = Otel.Exporter.OTLP.Encoder.encode_traces([span_with_link], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      link = hd(span.links)
      assert link.trace_id == <<100::128>>
      assert link.span_id == <<200::64>>
    end

    test "encodes various attribute types" do
      span =
        %{
          @span
          | attributes: %{
              "string" => "val",
              "int" => 42,
              "float" => 3.14,
              "bool" => true,
              "atom" => :test,
              "list" => [1, 2, 3]
            }
        }

      binary = Otel.Exporter.OTLP.Encoder.encode_traces([span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      attrs = Map.new(span.attributes, &{&1.key, &1.value.value})

      assert {:string_value, "val"} = attrs["string"]
      assert {:int_value, 42} = attrs["int"]
      assert {:double_value, 3.14} = attrs["float"]
      assert {:bool_value, true} = attrs["bool"]
      assert {:string_value, "test"} = attrs["atom"]
      assert {:array_value, _} = attrs["list"]
    end

    test "handles unknown attribute type via inspect" do
      span = %{@span | attributes: %{"tuple" => {1, 2}}}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      attr = hd(span.attributes)
      assert {:string_value, "{1, 2}"} = attr.value.value
    end

    test "groups spans by instrumentation scope" do
      scope_a = %Otel.API.InstrumentationScope{name: "lib_a"}
      scope_b = %Otel.API.InstrumentationScope{name: "lib_b"}
      span_a = %{@span | instrumentation_scope: scope_a}
      span_b = %{@span | instrumentation_scope: scope_b}

      binary = Otel.Exporter.OTLP.Encoder.encode_traces([span_a, span_b], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      scope_spans = hd(decoded.resource_spans).scope_spans
      assert length(scope_spans) == 2
    end

    test "encodes span kind variants" do
      for {kind, expected} <- [
            {:internal, :SPAN_KIND_INTERNAL},
            {:server, :SPAN_KIND_SERVER},
            {:client, :SPAN_KIND_CLIENT},
            {:producer, :SPAN_KIND_PRODUCER},
            {:consumer, :SPAN_KIND_CONSUMER}
          ] do
        span = %{@span | kind: kind}
        binary = Otel.Exporter.OTLP.Encoder.encode_traces([span], @resource)

        decoded =
          Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

        proto_span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
        assert proto_span.kind == expected
      end
    end

    test "encodes parent span id" do
      child_span = %{@span | parent_span_id: 0xDEADBEEF}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([child_span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert span.parent_span_id == <<0xDEADBEEF::64>>
    end

    test "encodes parent_span_id 0 as empty" do
      span = %{@span | parent_span_id: 0}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      proto_span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert proto_span.parent_span_id == <<>>
    end

    test "encodes unknown span kind as unspecified" do
      span = %{@span | kind: :unknown}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      proto_span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert proto_span.kind == :SPAN_KIND_UNSPECIFIED
    end

    test "encodes nil scope" do
      span = %{@span | instrumentation_scope: nil}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      scope_spans = hd(hd(decoded.resource_spans).scope_spans)
      assert scope_spans.scope == nil
    end
  end

  describe "encode_metrics/1" do
    @counter_metric %{
      name: "http.requests",
      description: "Request count",
      unit: "1",
      scope: %Otel.API.InstrumentationScope{name: "test_lib", version: "1.0.0"},
      resource: Otel.SDK.Resource.create(%{"service.name" => "test"}),
      kind: :counter,
      temporality: :cumulative,
      is_monotonic: true,
      datapoints: [
        %{
          attributes: %{"method" => "GET"},
          value: 42,
          start_time: 1_000_000,
          time: 2_000_000,
          exemplars: []
        }
      ]
    }

    @gauge_metric %{
      name: "cpu.usage",
      description: "CPU usage",
      unit: "%",
      scope: %Otel.API.InstrumentationScope{name: "test_lib"},
      resource: Otel.SDK.Resource.create(%{"service.name" => "test"}),
      kind: :gauge,
      temporality: nil,
      is_monotonic: nil,
      datapoints: [
        %{
          attributes: %{"host" => "a"},
          value: 75.5,
          start_time: 1_000_000,
          time: 2_000_000,
          exemplars: []
        }
      ]
    }

    @histogram_metric %{
      name: "http.duration",
      description: "Request duration",
      unit: "ms",
      scope: %Otel.API.InstrumentationScope{name: "test_lib"},
      resource: Otel.SDK.Resource.create(%{"service.name" => "test"}),
      kind: :histogram,
      temporality: :cumulative,
      is_monotonic: nil,
      datapoints: [
        %{
          attributes: %{},
          value: %{
            bucket_counts: [1, 2, 0, 1],
            boundaries: [10, 50, 100],
            sum: 150.5,
            count: 4,
            min: 5,
            max: 120
          },
          start_time: 1_000_000,
          time: 2_000_000,
          exemplars: []
        }
      ]
    }

    test "produces valid protobuf binary for counter" do
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([@counter_metric])
      assert is_binary(binary)
      assert byte_size(binary) > 0
    end

    test "counter decoded as Sum" do
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([@counter_metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      assert metric.name == "http.requests"
      assert metric.description == "Request count"
      assert metric.unit == "1"
      assert {:sum, sum} = metric.data
      assert sum.aggregation_temporality == :AGGREGATION_TEMPORALITY_CUMULATIVE
      assert sum.is_monotonic == true
      dp = hd(sum.data_points)
      assert {:as_int, 42} = dp.value
      assert dp.start_time_unix_nano == 1_000_000
      assert dp.time_unix_nano == 2_000_000
    end

    test "gauge decoded as Gauge" do
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([@gauge_metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      assert {:gauge, gauge} = metric.data
      dp = hd(gauge.data_points)
      assert {:as_double, 75.5} = dp.value
    end

    test "histogram decoded as Histogram" do
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([@histogram_metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      assert {:histogram, histogram} = metric.data
      assert histogram.aggregation_temporality == :AGGREGATION_TEMPORALITY_CUMULATIVE
      dp = hd(histogram.data_points)
      assert dp.count == 4
      assert dp.sum == 150.5
      assert dp.bucket_counts == [1, 2, 0, 1]
      assert dp.explicit_bounds == [10.0, 50.0, 100.0]
      assert dp.min == 5.0
      assert dp.max == 120.0
    end

    test "delta temporality encoded correctly" do
      metric = %{@counter_metric | temporality: :delta}
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      {:sum, sum} = metric.data
      assert sum.aggregation_temporality == :AGGREGATION_TEMPORALITY_DELTA
    end

    test "updown_counter encoded as non-monotonic Sum" do
      metric = %{@counter_metric | kind: :updown_counter, is_monotonic: false}
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      {:sum, sum} = metric.data
      assert sum.is_monotonic == false
    end

    test "observable_counter encoded as Sum" do
      metric = %{@counter_metric | kind: :observable_counter}
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      assert {:sum, _} = metric.data
    end

    test "observable_updown_counter encoded as non-monotonic Sum" do
      metric = %{@counter_metric | kind: :observable_updown_counter, is_monotonic: false}
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      {:sum, sum} = metric.data
      assert sum.is_monotonic == false
    end

    test "observable_gauge encoded as Gauge" do
      metric = %{@gauge_metric | kind: :observable_gauge}
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      metric = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics)
      assert {:gauge, _} = metric.data
    end

    test "propagates schema_url on ScopeMetrics" do
      scope = %Otel.API.InstrumentationScope{
        name: "lib",
        schema_url: "https://opentelemetry.io/schemas/1.21.0"
      }

      metric = %{@counter_metric | scope: scope}
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      scope_metrics = hd(hd(decoded.resource_metrics).scope_metrics)
      assert scope_metrics.schema_url == "https://opentelemetry.io/schemas/1.21.0"
    end

    test "encodes resource and scope" do
      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([@counter_metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      resource_metrics = hd(decoded.resource_metrics)
      attrs = resource_metrics.resource.attributes
      assert Enum.any?(attrs, &(&1.key == "service.name"))

      scope_metrics = hd(resource_metrics.scope_metrics)
      assert scope_metrics.scope.name == "test_lib"
    end

    test "groups metrics by resource and scope" do
      scope_a = %Otel.API.InstrumentationScope{name: "lib_a"}
      scope_b = %Otel.API.InstrumentationScope{name: "lib_b"}
      metric_a = %{@counter_metric | scope: scope_a}
      metric_b = %{@counter_metric | scope: scope_b, name: "other"}

      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric_a, metric_b])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      scope_metrics = hd(decoded.resource_metrics).scope_metrics
      assert length(scope_metrics) == 2
    end

    test "encodes exemplars with trace context" do
      exemplar = %Otel.SDK.Metrics.Exemplar{
        value: 42,
        time: 1_500_000,
        filtered_attributes: %{"extra" => "val"},
        span_id: 0xDEADBEEF,
        trace_id: 0x0AF7651916CD43DD8448EB211C80319C
      }

      metric =
        put_in(
          @counter_metric,
          [:datapoints, Access.at(0), :exemplars],
          [exemplar]
        )

      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      {_type, data} = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics).data
      dp = hd(data.data_points)

      ex = hd(dp.exemplars)
      assert ex.time_unix_nano == 1_500_000
      assert {:as_int, 42} = ex.value
      assert ex.span_id == <<0xDEADBEEF::64>>
      assert ex.trace_id == <<0x0AF7651916CD43DD8448EB211C80319C::128>>
      assert Enum.any?(ex.filtered_attributes, &(&1.key == "extra"))
    end

    test "encodes exemplar without trace context" do
      exemplar = %Otel.SDK.Metrics.Exemplar{
        value: 10.5,
        time: 1_500_000,
        filtered_attributes: %{},
        span_id: nil,
        trace_id: nil
      }

      metric =
        put_in(
          @counter_metric,
          [:datapoints, Access.at(0), :exemplars],
          [exemplar]
        )

      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      {_type, data} = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics).data
      dp = hd(data.data_points)

      ex = hd(dp.exemplars)
      assert {:as_double, 10.5} = ex.value
      assert ex.span_id == <<>>
      assert ex.trace_id == <<>>
    end

    test "encodes float value as as_double" do
      metric =
        put_in(
          @counter_metric,
          [:datapoints, Access.at(0), :value],
          3.14
        )

      binary = Otel.Exporter.OTLP.Encoder.encode_metrics([metric])

      decoded =
        Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)

      {_type, data} = hd(hd(hd(decoded.resource_metrics).scope_metrics).metrics).data
      dp = hd(data.data_points)

      assert {:as_double, 3.14} = dp.value
    end
  end

  describe "encode_logs/1" do
    @log_record %{
      body: "test message",
      severity_number: 9,
      severity_text: "INFO",
      timestamp: 1_000_000,
      observed_timestamp: 2_000_000,
      attributes: %{"method" => "GET"},
      event_name: nil,
      scope: %Otel.API.InstrumentationScope{name: "test_lib", version: "1.0.0"},
      resource: Otel.SDK.Resource.create(%{"service.name" => "test"}),
      trace_id: 0,
      span_id: 0,
      trace_flags: 0,
      dropped_attributes_count: 0
    }

    test "produces valid protobuf binary" do
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([@log_record])
      assert is_binary(binary)
      assert byte_size(binary) > 0
    end

    test "log record fields decoded correctly" do
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([@log_record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      record = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert record.time_unix_nano == 1_000_000
      assert record.observed_time_unix_nano == 2_000_000
      assert record.severity_number == :SEVERITY_NUMBER_INFO
      assert record.severity_text == "INFO"
      assert record.body.value == {:string_value, "test message"}
      assert record.dropped_attributes_count == 0
    end

    test "encodes resource and scope" do
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([@log_record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      resource_logs = hd(decoded.resource_logs)
      attrs = resource_logs.resource.attributes
      assert Enum.any?(attrs, &(&1.key == "service.name"))

      scope_logs = hd(resource_logs.scope_logs)
      assert scope_logs.scope.name == "test_lib"
      assert scope_logs.scope.version == "1.0.0"
    end

    test "encodes trace context when present" do
      record = %{
        @log_record
        | trace_id: 0x0AF7651916CD43DD8448EB211C80319C,
          span_id: 0xB7AD6B7169203331,
          trace_flags: 1
      }

      binary = Otel.Exporter.OTLP.Encoder.encode_logs([record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      log = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert log.trace_id == <<0x0AF7651916CD43DD8448EB211C80319C::128>>
      assert log.span_id == <<0xB7AD6B7169203331::64>>
      assert log.flags == 1
    end

    test "omits trace context when zero" do
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([@log_record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      log = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert log.trace_id == <<>>
      assert log.span_id == <<>>
    end

    test "encodes nil body as absent" do
      record = %{@log_record | body: nil}
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      log = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert log.body == nil
    end

    test "encodes map body as string via inspect" do
      record = %{@log_record | body: %{nested: "value"}}
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      log = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert log.body != nil
    end

    test "encodes severity number unspecified for nil" do
      record = %{@log_record | severity_number: nil}
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      log = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert log.severity_number == :SEVERITY_NUMBER_UNSPECIFIED
    end

    test "encodes event_name" do
      record = %{@log_record | event_name: "http.request"}
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      log = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert log.event_name == "http.request"
    end

    test "groups by resource and scope" do
      scope_a = %Otel.API.InstrumentationScope{name: "lib_a"}
      scope_b = %Otel.API.InstrumentationScope{name: "lib_b"}
      record_a = %{@log_record | scope: scope_a}
      record_b = %{@log_record | scope: scope_b, body: "other"}

      binary = Otel.Exporter.OTLP.Encoder.encode_logs([record_a, record_b])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      scope_logs = hd(decoded.resource_logs).scope_logs
      assert length(scope_logs) == 2
    end

    test "encodes dropped_attributes_count" do
      record = %{@log_record | dropped_attributes_count: 5}
      binary = Otel.Exporter.OTLP.Encoder.encode_logs([record])

      decoded =
        Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)

      log = hd(hd(hd(decoded.resource_logs).scope_logs).log_records)
      assert log.dropped_attributes_count == 5
    end
  end
end
