defmodule Otel.OTLP.EncoderTest do
  use ExUnit.Case, async: true

  @resource %Otel.Resource{
    attributes: %{
      "service.name" => "test-service",
      "telemetry.sdk.language" => "elixir"
    }
  }

  describe "encode_traces/2" do
    @span %Otel.Trace.Span{
      trace_id: 0x0AF7651916CD43DD8448EB211C80319C,
      span_id: 0xB7AD6B7169203331,
      parent_span_id: nil,
      tracestate: Otel.Trace.TraceState.new(),
      name: "test_span",
      kind: :server,
      start_time: 1_000_000_000,
      end_time: 2_000_000_000,
      attributes: %{"http.method" => "GET", "http.status_code" => 200},
      events: [
        %Otel.Trace.Event{
          name: "event1",
          timestamp: 1_500_000_000,
          attributes: %{"key" => "val"}
        }
      ],
      links: [],
      status: %Otel.Trace.Status{code: :ok},
      trace_flags: 1,
      instrumentation_scope: %Otel.InstrumentationScope{
        name: "test_lib",
        version: "1.0.0"
      }
    }

    defp roundtrip_traces(spans) do
      binary = Otel.OTLP.Encoder.encode_traces(spans, @resource)
      Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest.decode(binary)
    end

    defp first_span(spans),
      do: hd(hd(hd(roundtrip_traces(spans).resource_spans).scope_spans).spans)

    test "produces a valid protobuf binary" do
      binary = Otel.OTLP.Encoder.encode_traces([@span], @resource)
      assert is_binary(binary) and byte_size(binary) > 0
      assert length(roundtrip_traces([@span]).resource_spans) == 1
    end

    test "encodes span identity, kind, timestamps, parent" do
      span = first_span([@span])
      assert span.name == "test_span"
      assert span.kind == :SPAN_KIND_SERVER
      assert span.start_time_unix_nano == 1_000_000_000
      assert span.end_time_unix_nano == 2_000_000_000
      assert span.trace_id == <<0x0AF7651916CD43DD8448EB211C80319C::128>>
      assert span.span_id == <<0xB7AD6B7169203331::64>>
      assert span.parent_span_id == <<>>

      child = first_span([%{@span | parent_span_id: 0xDEADBEEF}])
      assert child.parent_span_id == <<0xDEADBEEF::64>>

      zero_parent = first_span([%{@span | parent_span_id: 0}])
      assert zero_parent.parent_span_id == <<>>
    end

    test "encodes resource attributes" do
      decoded = roundtrip_traces([@span])
      attrs = hd(decoded.resource_spans).resource.attributes
      service = Enum.find(attrs, &(&1.key == "service.name"))
      assert {:string_value, "test-service"} = service.value.value
    end

    test "encodes instrumentation scope name, version, and attributes" do
      decoded = roundtrip_traces([@span])
      scope = hd(hd(decoded.resource_spans).scope_spans).scope
      assert scope.name == "test_lib"
      assert scope.version == "1.0.0"

      with_attrs = %{
        @span
        | instrumentation_scope: %Otel.InstrumentationScope{
            name: "scoped_lib",
            version: "2.0.0",
            attributes: %{"library.tag" => "v2", "build" => 42}
          }
      }

      attr_scope = hd(hd(roundtrip_traces([with_attrs]).resource_spans).scope_spans).scope
      attr_map = Map.new(attr_scope.attributes, fn kv -> {kv.key, kv.value.value} end)
      assert {:string_value, "v2"} = attr_map["library.tag"]
      assert {:int_value, 42} = attr_map["build"]
    end

    test "nil scope encodes as nil scope" do
      decoded = roundtrip_traces([%{@span | instrumentation_scope: nil}])
      assert hd(hd(decoded.resource_spans).scope_spans).scope == nil
    end

    test "encodes events with timestamps" do
      event = hd(first_span([@span]).events)
      assert event.name == "event1"
      assert event.time_unix_nano == 1_500_000_000
    end

    test "encodes links with linked context" do
      linked = Otel.Trace.SpanContext.new(100, 200, 1)
      link_span = %{@span | links: [%Otel.Trace.Link{context: linked, attributes: %{}}]}

      link = hd(first_span([link_span]).links)
      assert link.trace_id == <<100::128>>
      assert link.span_id == <<200::64>>
    end

    test "encodes status: :ok / :error / :unset → nil" do
      assert first_span([@span]).status.code == :STATUS_CODE_OK

      err =
        first_span([
          %{@span | status: %Otel.Trace.Status{code: :error, description: "boom"}}
        ])

      assert err.status.code == :STATUS_CODE_ERROR
      assert err.status.message == "boom"

      unset = first_span([%{@span | status: %Otel.Trace.Status{code: :unset}}])
      assert unset.status == nil
    end

    test "encodes dropped counts on span/event/link" do
      span_with_drops = %{
        @span
        | dropped_attributes_count: 7,
          dropped_events_count: 3,
          dropped_links_count: 5,
          events: [
            %Otel.Trace.Event{
              name: "ev",
              timestamp: 1_500_000_000,
              dropped_attributes_count: 2
            }
          ],
          links: [
            %Otel.Trace.Link{
              context: Otel.Trace.SpanContext.new(1, 2, 1),
              dropped_attributes_count: 4
            }
          ]
      }

      span = first_span([span_with_drops])
      assert span.dropped_attributes_count == 7
      assert span.dropped_events_count == 3
      assert span.dropped_links_count == 5
      assert hd(span.events).dropped_attributes_count == 2
      assert hd(span.links).dropped_attributes_count == 4
    end

    test "encodes every primitive_any case; nil → empty AnyValue (oneof unset)" do
      attrs_span = %{
        @span
        | attributes: %{
            "string" => "val",
            "int" => 42,
            "float" => 3.14,
            "bool" => true,
            "list" => [1, 2, 3],
            "map" => %{"a" => 1, "b" => "x"},
            "nil" => nil
          }
      }

      attrs = Map.new(first_span([attrs_span]).attributes, &{&1.key, &1.value})
      assert {:string_value, "val"} = attrs["string"].value
      assert {:int_value, 42} = attrs["int"].value
      assert {:double_value, 3.14} = attrs["float"].value
      assert {:bool_value, true} = attrs["bool"].value
      assert {:array_value, _} = attrs["list"].value
      assert {:kvlist_value, _} = attrs["map"].value
      # nil → %AnyValue{value: nil} — oneof unset, the OTLP wire
      # representation of "this AnyValue is empty" per
      # `common/README.md` L50-L51, L67-L68.
      assert is_nil(attrs["nil"].value)
    end

    test "rejects non-primitive_any values (atoms, tuples, refs)" do
      for invalid <- [:bare_atom, {1, 2}, make_ref()] do
        assert_raise FunctionClauseError, fn ->
          Otel.OTLP.Encoder.encode_traces(
            [%{@span | attributes: %{"bad" => invalid}}],
            @resource
          )
        end
      end
    end

    test "binary attributes: utf8 → string; {:bytes, _} → bytes; invalid utf8 raises unless tagged" do
      utf8 = "hello 안녕"
      utf8_attr = hd(first_span([%{@span | attributes: %{"greeting" => utf8}}]).attributes)
      assert {:string_value, ^utf8} = utf8_attr.value.value

      raw = <<0xFF, 0x00, 0xDE, 0xAD>>
      bytes_attr = hd(first_span([%{@span | attributes: %{"p" => {:bytes, raw}}}]).attributes)
      assert {:bytes_value, ^raw} = bytes_attr.value.value

      assert_raise Protobuf.EncodeError, ~r/invalid UTF-8/, fn ->
        Otel.OTLP.Encoder.encode_traces(
          [%{@span | attributes: %{"raw" => <<0xFF, 0xFE>>}}],
          @resource
        )
      end

      bad = <<0xFF, 0xFE>>
      bad_attr = hd(first_span([%{@span | attributes: %{"r" => {:bytes, bad}}}]).attributes)
      assert {:bytes_value, ^bad} = bad_attr.value.value
    end

    test "encodes span kind variants and unknown→unspecified" do
      for {kind, expected} <- [
            {:internal, :SPAN_KIND_INTERNAL},
            {:server, :SPAN_KIND_SERVER},
            {:client, :SPAN_KIND_CLIENT},
            {:producer, :SPAN_KIND_PRODUCER},
            {:consumer, :SPAN_KIND_CONSUMER},
            {:unknown, :SPAN_KIND_UNSPECIFIED}
          ] do
        assert first_span([%{@span | kind: kind}]).kind == expected
      end
    end

    test "groups spans by instrumentation scope" do
      scope_a = %Otel.InstrumentationScope{name: "lib_a"}
      scope_b = %Otel.InstrumentationScope{name: "lib_b"}

      decoded =
        roundtrip_traces([
          %{@span | instrumentation_scope: scope_a},
          %{@span | instrumentation_scope: scope_b}
        ])

      assert length(hd(decoded.resource_spans).scope_spans) == 2
    end
  end

  describe "encode_metrics/1" do
    @counter %{
      name: "http.requests",
      description: "Request count",
      unit: "1",
      scope: %Otel.InstrumentationScope{name: "test_lib", version: "1.0.0"},
      resource: %Otel.Resource{attributes: %{"service.name" => "test"}},
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

    @gauge %{
      name: "cpu.usage",
      description: "CPU usage",
      unit: "%",
      scope: %Otel.InstrumentationScope{name: "test_lib"},
      resource: %Otel.Resource{attributes: %{"service.name" => "test"}},
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

    @histogram %{
      name: "http.duration",
      description: "Request duration",
      unit: "ms",
      scope: %Otel.InstrumentationScope{name: "test_lib"},
      resource: %Otel.Resource{attributes: %{"service.name" => "test"}},
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

    defp roundtrip_metrics(metrics) do
      binary = Otel.OTLP.Encoder.encode_metrics(metrics)
      Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest.decode(binary)
    end

    defp first_metric(metrics),
      do: hd(hd(hd(roundtrip_metrics(metrics).resource_metrics).scope_metrics).metrics)

    test "produces a valid protobuf binary" do
      binary = Otel.OTLP.Encoder.encode_metrics([@counter])
      assert is_binary(binary) and byte_size(binary) > 0
    end

    test "counter encodes as monotonic Sum with int value and cumulative temporality" do
      metric = first_metric([@counter])
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

    test "gauge encodes as Gauge with double value" do
      assert {:gauge, gauge} = first_metric([@gauge]).data
      assert {:as_double, 75.5} = hd(gauge.data_points).value
    end

    test "histogram encodes bucket counts, bounds, sum/count, min/max" do
      assert {:histogram, h} = first_metric([@histogram]).data
      assert h.aggregation_temporality == :AGGREGATION_TEMPORALITY_CUMULATIVE
      dp = hd(h.data_points)
      assert dp.count == 4
      assert dp.sum == 150.5
      assert dp.bucket_counts == [1, 2, 0, 1]
      assert dp.explicit_bounds == [10.0, 50.0, 100.0]
      assert dp.min == 5.0
      assert dp.max == 120.0
    end

    # Regression for the e2e §Metrics row 6 crash: a Histogram
    # configured with `aggregation_options: %{record_min_max:
    # false}` carries `min: nil` / `max: nil` on the datapoint.
    # SDK aggregations' `normalize/1` converts the internal
    # `:unset` ETS sentinel to `nil` at collect time, so the
    # encoder only ever sees `nil`. Encoder used to crash in
    # `encode_optional_double/1` with `ArithmeticError` from
    # `nil + 0.0`.
    test "histogram nil min/max → absent in proto" do
      nil_hist = %{
        @counter
        | kind: :histogram,
          datapoints: [
            %{
              attributes: %{},
              value: %{
                bucket_counts: [1],
                boundaries: [],
                sum: 5,
                count: 1,
                min: nil,
                max: nil
              },
              start_time: 1_000_000,
              time: 2_000_000,
              exemplars: []
            }
          ]
      }

      {:histogram, h} = first_metric([nil_hist]).data
      dp = hd(h.data_points)
      assert dp.min == nil
      assert dp.max == nil
    end

    # Defensive coverage for datapoint-shape dispatch — if a
    # datapoint's value shape disagrees with `metric.kind`,
    # the encoder routes by shape, not kind. (Reachable
    # historically through Views; preserved as a guard.)
    test "histogram-shaped datapoints on a counter-kind metric encode as histogram" do
      counter_with_hist_dp = %{
        @counter
        | datapoints: [
            %{
              attributes: %{},
              value: %{
                bucket_counts: [1],
                boundaries: [],
                sum: 5,
                count: 1,
                min: nil,
                max: nil
              },
              start_time: 1_000_000,
              time: 2_000_000,
              exemplars: []
            }
          ]
      }

      assert {:histogram, _} = first_metric([counter_with_hist_dp]).data
    end

    test "exponential histogram encodes scale, offsets, zero count/threshold, min/max" do
      exp = %{
        @histogram
        | datapoints: [
            %{
              attributes: %{},
              value: %{
                scale: 3,
                positive: %{offset: -1, bucket_counts: [2, 5, 1]},
                negative: %{offset: 0, bucket_counts: []},
                zero_count: 4,
                zero_threshold: 0.0,
                sum: 12.5,
                count: 12,
                min: 0.5,
                max: 8.0
              },
              start_time: 1_000_000,
              time: 2_000_000,
              exemplars: []
            }
          ]
      }

      {:exponential_histogram, eh} = first_metric([exp]).data
      assert eh.aggregation_temporality == :AGGREGATION_TEMPORALITY_CUMULATIVE
      dp = hd(eh.data_points)
      assert dp.count == 12
      assert dp.sum == 12.5
      assert dp.scale == 3
      assert dp.zero_count == 4
      assert dp.zero_threshold == 0.0
      assert dp.positive.offset == -1
      assert dp.positive.bucket_counts == [2, 5, 1]
      assert dp.negative.offset == 0
      assert dp.negative.bucket_counts == []
      assert dp.min == 0.5
      assert dp.max == 8.0
    end

    test "instrument kind variants map to Sum/Gauge with correct monotonicity" do
      for {kind, mono?} <- [{:counter, true}, {:updown_counter, false}] do
        {:sum, sum} = first_metric([%{@counter | kind: kind, is_monotonic: mono?}]).data
        assert sum.is_monotonic == mono?
      end

      assert {:gauge, _} = first_metric([%{@gauge | kind: :gauge}]).data
    end

    test "temporality :delta and unknown → unspecified" do
      {:sum, delta} = first_metric([%{@counter | temporality: :delta}]).data
      assert delta.aggregation_temporality == :AGGREGATION_TEMPORALITY_DELTA

      {:sum, unspec} = first_metric([%{@counter | temporality: :unknown_value}]).data
      assert unspec.aggregation_temporality == :AGGREGATION_TEMPORALITY_UNSPECIFIED
    end

    test "datapoint float value → as_double" do
      metric = put_in(@counter, [:datapoints, Access.at(0), :value], 3.14)
      {:sum, sum} = first_metric([metric]).data
      assert {:as_double, 3.14} = hd(sum.data_points).value
    end

    test "exemplars with and without trace context" do
      with_ctx = %Otel.Metrics.Exemplar{
        value: 42,
        time: 1_500_000,
        filtered_attributes: %{"extra" => "val"},
        span_id: 0xDEADBEEF,
        trace_id: 0x0AF7651916CD43DD8448EB211C80319C
      }

      no_ctx = %Otel.Metrics.Exemplar{
        value: 10.5,
        time: 1_500_000,
        filtered_attributes: %{},
        span_id: nil,
        trace_id: nil
      }

      m1 = put_in(@counter, [:datapoints, Access.at(0), :exemplars], [with_ctx])
      {_, d1} = first_metric([m1]).data
      ex1 = hd(hd(d1.data_points).exemplars)
      assert ex1.time_unix_nano == 1_500_000
      assert {:as_int, 42} = ex1.value
      assert ex1.span_id == <<0xDEADBEEF::64>>
      assert ex1.trace_id == <<0x0AF7651916CD43DD8448EB211C80319C::128>>
      assert Enum.any?(ex1.filtered_attributes, &(&1.key == "extra"))

      m2 = put_in(@counter, [:datapoints, Access.at(0), :exemplars], [no_ctx])
      {_, d2} = first_metric([m2]).data
      ex2 = hd(hd(d2.data_points).exemplars)
      assert {:as_double, 10.5} = ex2.value
      assert ex2.span_id == <<>>
      assert ex2.trace_id == <<>>
    end

    test "scope schema_url propagated; nil scope → empty schema_url; resource attributes encoded" do
      scope = %Otel.InstrumentationScope{
        name: "lib",
        schema_url: "https://opentelemetry.io/schemas/1.21.0"
      }

      with_schema = roundtrip_metrics([%{@counter | scope: scope}])

      assert hd(hd(with_schema.resource_metrics).scope_metrics).schema_url ==
               "https://opentelemetry.io/schemas/1.21.0"

      nil_scope = roundtrip_metrics([%{@counter | scope: nil}])
      assert hd(hd(nil_scope.resource_metrics).scope_metrics).schema_url == ""

      attrs = hd(roundtrip_metrics([@counter]).resource_metrics).resource.attributes
      assert Enum.any?(attrs, &(&1.key == "service.name"))
    end

    test "groups metrics by instrumentation scope" do
      scope_a = %Otel.InstrumentationScope{name: "lib_a"}
      scope_b = %Otel.InstrumentationScope{name: "lib_b"}

      decoded =
        roundtrip_metrics([
          %{@counter | scope: scope_a},
          %{@counter | scope: scope_b, name: "other"}
        ])

      assert length(hd(decoded.resource_metrics).scope_metrics) == 2
    end
  end

  describe "encode_logs/1" do
    @log_record %Otel.Logs.LogRecord{
      body: "test message",
      severity_number: 9,
      severity_text: "INFO",
      timestamp: 1_000_000,
      observed_timestamp: 2_000_000,
      attributes: %{"method" => "GET"},
      event_name: "",
      scope: %Otel.InstrumentationScope{name: "test_lib", version: "1.0.0"},
      resource: %Otel.Resource{attributes: %{"service.name" => "test"}},
      trace_id: 0,
      span_id: 0,
      trace_flags: 0,
      dropped_attributes_count: 0
    }

    defp roundtrip_logs(records) do
      binary = Otel.OTLP.Encoder.encode_logs(records)
      Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest.decode(binary)
    end

    defp first_log(records),
      do: hd(hd(hd(roundtrip_logs(records).resource_logs).scope_logs).log_records)

    test "produces a valid protobuf binary" do
      binary = Otel.OTLP.Encoder.encode_logs([@log_record])
      assert is_binary(binary) and byte_size(binary) > 0
    end

    test "log identity, timestamps, severity, body, dropped count" do
      record = first_log([@log_record])
      assert record.time_unix_nano == 1_000_000
      assert record.observed_time_unix_nano == 2_000_000
      assert record.severity_number == :SEVERITY_NUMBER_INFO
      assert record.severity_text == "INFO"
      assert record.body.value == {:string_value, "test message"}
      assert record.dropped_attributes_count == 0

      drop = first_log([%{@log_record | dropped_attributes_count: 5}])
      assert drop.dropped_attributes_count == 5
    end

    test "severity_number 0 sentinel → unspecified" do
      assert first_log([%{@log_record | severity_number: 0}]).severity_number ==
               :SEVERITY_NUMBER_UNSPECIFIED
    end

    test "event_name encoded; empty string default" do
      assert first_log([%{@log_record | event_name: "http.request"}]).event_name == "http.request"
    end

    test "body variants: string / nil / map / {:bytes, _} / nested {:bytes, _}" do
      raw = <<0xCA, 0xFE, 0xBA, 0xBE>>
      bytes_log = first_log([%{@log_record | body: {:bytes, raw}}])
      assert bytes_log.body.value == {:bytes_value, raw}

      payload = <<1, 2, 3>>
      nested = %{"event" => "upload", "content" => {:bytes, payload}, "size" => 3}
      nested_log = first_log([%{@log_record | body: nested}])
      {:kvlist_value, %{values: kvs}} = nested_log.body.value
      by_key = Map.new(kvs, fn %{key: k, value: %{value: v}} -> {k, v} end)
      assert by_key["event"] == {:string_value, "upload"}
      assert by_key["content"] == {:bytes_value, payload}
      assert by_key["size"] == {:int_value, 3}

      assert first_log([%{@log_record | body: nil}]).body == nil
      assert first_log([%{@log_record | body: %{nested: "value"}}]).body != nil
    end

    test "trace context encoded when present; empty when zero" do
      with_ctx =
        first_log([
          %{
            @log_record
            | trace_id: 0x0AF7651916CD43DD8448EB211C80319C,
              span_id: 0xB7AD6B7169203331,
              trace_flags: 1
          }
        ])

      assert with_ctx.trace_id == <<0x0AF7651916CD43DD8448EB211C80319C::128>>
      assert with_ctx.span_id == <<0xB7AD6B7169203331::64>>
      assert with_ctx.flags == 1

      zero = first_log([@log_record])
      assert zero.trace_id == <<>>
      assert zero.span_id == <<>>
    end

    test "resource attributes and scope encoded" do
      decoded = roundtrip_logs([@log_record])
      attrs = hd(decoded.resource_logs).resource.attributes
      assert Enum.any?(attrs, &(&1.key == "service.name"))

      scope = hd(hd(decoded.resource_logs).scope_logs).scope
      assert scope.name == "test_lib"
      assert scope.version == "1.0.0"
    end

    test "groups records by instrumentation scope" do
      scope_a = %Otel.InstrumentationScope{name: "lib_a"}
      scope_b = %Otel.InstrumentationScope{name: "lib_b"}

      decoded =
        roundtrip_logs([
          %{@log_record | scope: scope_a},
          %{@log_record | scope: scope_b, body: "other"}
        ])

      assert length(hd(decoded.resource_logs).scope_logs) == 2
    end
  end
end
