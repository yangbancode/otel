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
      %{name: "event1", time: 1_500_000_000, attributes: %{"key" => "val"}}
    ],
    links: [],
    status: {:ok, ""},
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
      error_span = %{@span | status: {:error, "something failed"}}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([error_span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert span.status.code == :STATUS_CODE_ERROR
      assert span.status.message == "something failed"
    end

    test "encodes nil status as no status" do
      nil_status_span = %{@span | status: nil}
      binary = Otel.Exporter.OTLP.Encoder.encode_traces([nil_status_span], @resource)

      decoded =
        Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)

      span = hd(hd(hd(decoded.resource_spans).scope_spans).spans)
      assert span.status == nil
    end

    test "encodes links" do
      linked_ctx = Otel.API.Trace.SpanContext.new(100, 200, 1)
      span_with_link = %{@span | links: [{linked_ctx, %{"link.key" => "val"}}]}
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
end
