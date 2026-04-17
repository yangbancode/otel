defmodule Otel.Exporter.OTLP.Encoder do
  @moduledoc false

  @doc """
  Encodes a list of SDK spans and a Resource into an
  ExportTraceServiceRequest protobuf binary.
  """
  @spec encode_traces(
          spans :: [Otel.SDK.Trace.Span.t()],
          resource :: Otel.SDK.Resource.t()
        ) :: binary()
  def encode_traces(spans, resource) do
    resource_spans = build_resource_spans(spans, resource)

    %Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest{
      resource_spans: resource_spans
    }
    |> Protobuf.encode()
  end

  @spec build_resource_spans(
          spans :: [Otel.SDK.Trace.Span.t()],
          resource :: Otel.SDK.Resource.t()
        ) :: [Opentelemetry.Proto.Trace.V1.ResourceSpans.t()]
  defp build_resource_spans(spans, resource) do
    scope_spans = group_by_scope(spans)

    [
      %Opentelemetry.Proto.Trace.V1.ResourceSpans{
        resource: encode_resource(resource),
        scope_spans: scope_spans,
        schema_url: resource.schema_url
      }
    ]
  end

  @spec group_by_scope(spans :: [Otel.SDK.Trace.Span.t()]) ::
          [Opentelemetry.Proto.Trace.V1.ScopeSpans.t()]
  defp group_by_scope(spans) do
    spans
    |> Enum.group_by(& &1.instrumentation_scope)
    |> Enum.map(fn {scope, scope_spans} ->
      %Opentelemetry.Proto.Trace.V1.ScopeSpans{
        scope: encode_scope(scope),
        spans: Enum.map(scope_spans, &encode_span/1)
      }
    end)
  end

  # --- Resource ---

  @spec encode_resource(resource :: Otel.SDK.Resource.t()) ::
          Opentelemetry.Proto.Resource.V1.Resource.t()
  defp encode_resource(resource) do
    %Opentelemetry.Proto.Resource.V1.Resource{
      attributes: encode_attributes(resource.attributes)
    }
  end

  # --- Scope ---

  @spec encode_scope(scope :: Otel.API.InstrumentationScope.t() | nil) ::
          Opentelemetry.Proto.Common.V1.InstrumentationScope.t() | nil
  defp encode_scope(nil), do: nil

  defp encode_scope(scope) do
    %Opentelemetry.Proto.Common.V1.InstrumentationScope{
      name: scope.name || "",
      version: scope.version || ""
    }
  end

  # --- Span ---

  @spec encode_span(span :: Otel.SDK.Trace.Span.t()) ::
          Opentelemetry.Proto.Trace.V1.Span.t()
  defp encode_span(span) do
    %Opentelemetry.Proto.Trace.V1.Span{
      trace_id: encode_trace_id(span.trace_id),
      span_id: encode_span_id(span.span_id),
      parent_span_id: encode_parent_span_id(span.parent_span_id),
      trace_state: Otel.API.Trace.TraceState.encode(span.tracestate),
      name: span.name,
      kind: encode_span_kind(span.kind),
      start_time_unix_nano: span.start_time,
      end_time_unix_nano: span.end_time || 0,
      attributes: encode_attributes(span.attributes || []),
      events: Enum.map(span.events || [], &encode_event/1),
      links: Enum.map(span.links || [], &encode_link/1),
      status: encode_status(span.status),
      flags: span.trace_flags
    }
  end

  # --- Event ---

  @spec encode_event(
          event :: %{name: term(), time: integer(), attributes: [Otel.API.Common.Attribute.t()]}
        ) ::
          Opentelemetry.Proto.Trace.V1.Span.Event.t()
  defp encode_event(event) do
    %Opentelemetry.Proto.Trace.V1.Span.Event{
      time_unix_nano: event.time,
      name: to_string(event.name),
      attributes: encode_attributes(event.attributes || [])
    }
  end

  # --- Link ---

  @spec encode_link(link :: {Otel.API.Trace.SpanContext.t(), [Otel.API.Common.Attribute.t()]}) ::
          Opentelemetry.Proto.Trace.V1.Span.Link.t()
  defp encode_link({span_ctx, attrs}) do
    %Opentelemetry.Proto.Trace.V1.Span.Link{
      trace_id: encode_trace_id(span_ctx.trace_id),
      span_id: encode_span_id(span_ctx.span_id),
      trace_state: Otel.API.Trace.TraceState.encode(span_ctx.tracestate),
      attributes: encode_attributes(attrs || [])
    }
  end

  # --- Status ---

  @spec encode_status(status :: {atom(), String.t()} | nil) ::
          Opentelemetry.Proto.Trace.V1.Status.t() | nil
  defp encode_status(nil), do: nil

  defp encode_status({:ok, _message}) do
    %Opentelemetry.Proto.Trace.V1.Status{code: :STATUS_CODE_OK, message: ""}
  end

  defp encode_status({:error, message}) do
    %Opentelemetry.Proto.Trace.V1.Status{code: :STATUS_CODE_ERROR, message: message}
  end

  # --- Attributes ---

  @spec encode_attributes(attributes :: [Otel.API.Common.Attribute.t()]) ::
          [Opentelemetry.Proto.Common.V1.KeyValue.t()]
  defp encode_attributes(attributes) when is_list(attributes) do
    Enum.map(attributes, fn %Otel.API.Common.Attribute{
                              key: key,
                              value: %Otel.API.Common.AnyValue{} = value
                            } ->
      %Opentelemetry.Proto.Common.V1.KeyValue{
        key: key,
        value: encode_any_value(value)
      }
    end)
  end

  @spec encode_any_value(any_value :: Otel.API.Common.AnyValue.t()) ::
          Opentelemetry.Proto.Common.V1.AnyValue.t()
  defp encode_any_value(%Otel.API.Common.AnyValue{type: :string, value: v}) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:string_value, v}}
  end

  defp encode_any_value(%Otel.API.Common.AnyValue{type: :bool, value: v}) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:bool_value, v}}
  end

  defp encode_any_value(%Otel.API.Common.AnyValue{type: :int, value: v}) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:int_value, v}}
  end

  defp encode_any_value(%Otel.API.Common.AnyValue{type: :double, value: v}) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:double_value, v}}
  end

  defp encode_any_value(%Otel.API.Common.AnyValue{type: :bytes, value: v}) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:bytes_value, v}}
  end

  defp encode_any_value(%Otel.API.Common.AnyValue{type: :array, value: v}) do
    array = %Opentelemetry.Proto.Common.V1.ArrayValue{
      values: Enum.map(v, &encode_any_value/1)
    }

    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:array_value, array}}
  end

  defp encode_any_value(%Otel.API.Common.AnyValue{type: :kvlist, value: v}) do
    kvlist = %Opentelemetry.Proto.Common.V1.KeyValueList{
      values:
        Enum.map(v, fn {k, vv} ->
          %Opentelemetry.Proto.Common.V1.KeyValue{key: k, value: encode_any_value(vv)}
        end)
    }

    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:kvlist_value, kvlist}}
  end

  defp encode_any_value(%Otel.API.Common.AnyValue{type: :empty}) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: nil}
  end

  # --- Metrics ---

  @doc """
  Encodes a list of collected metrics into an
  ExportMetricsServiceRequest protobuf binary.
  """
  @spec encode_metrics(metrics :: [Otel.SDK.Metrics.MetricReader.metric()]) :: binary()
  def encode_metrics(metrics) do
    resource_metrics = build_resource_metrics(metrics)

    %Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest{
      resource_metrics: resource_metrics
    }
    |> Protobuf.encode()
  end

  @spec build_resource_metrics(metrics :: [Otel.SDK.Metrics.MetricReader.metric()]) ::
          [Opentelemetry.Proto.Metrics.V1.ResourceMetrics.t()]
  defp build_resource_metrics(metrics) do
    metrics
    |> Enum.group_by(& &1.resource)
    |> Enum.map(fn {resource, resource_group} ->
      %Opentelemetry.Proto.Metrics.V1.ResourceMetrics{
        resource: encode_resource(resource),
        scope_metrics: group_metrics_by_scope(resource_group),
        schema_url: resource.schema_url
      }
    end)
  end

  @spec group_metrics_by_scope(metrics :: [Otel.SDK.Metrics.MetricReader.metric()]) ::
          [Opentelemetry.Proto.Metrics.V1.ScopeMetrics.t()]
  defp group_metrics_by_scope(metrics) do
    metrics
    |> Enum.group_by(& &1.scope)
    |> Enum.map(fn {scope, scope_group} ->
      %Opentelemetry.Proto.Metrics.V1.ScopeMetrics{
        scope: encode_scope(scope),
        metrics: Enum.map(scope_group, &encode_metric/1),
        schema_url: scope_schema_url(scope)
      }
    end)
  end

  @spec scope_schema_url(scope :: Otel.API.InstrumentationScope.t() | nil) :: String.t()
  defp scope_schema_url(nil), do: ""
  defp scope_schema_url(scope), do: scope.schema_url || ""

  @spec encode_metric(metric :: Otel.SDK.Metrics.MetricReader.metric()) ::
          Opentelemetry.Proto.Metrics.V1.Metric.t()
  defp encode_metric(metric) do
    %Opentelemetry.Proto.Metrics.V1.Metric{
      name: metric.name,
      description: metric.description,
      unit: metric.unit,
      data: encode_metric_data(metric)
    }
  end

  @spec encode_metric_data(metric :: Otel.SDK.Metrics.MetricReader.metric()) ::
          {:sum, Opentelemetry.Proto.Metrics.V1.Sum.t()}
          | {:gauge, Opentelemetry.Proto.Metrics.V1.Gauge.t()}
          | {:histogram, Opentelemetry.Proto.Metrics.V1.Histogram.t()}
  defp encode_metric_data(%{kind: kind} = metric)
       when kind in [:counter, :updown_counter, :observable_counter, :observable_updown_counter] do
    {:sum,
     %Opentelemetry.Proto.Metrics.V1.Sum{
       data_points: Enum.map(metric.datapoints, &encode_number_data_point/1),
       aggregation_temporality: encode_temporality(metric.temporality),
       is_monotonic: metric.is_monotonic || false
     }}
  end

  defp encode_metric_data(%{kind: kind} = metric)
       when kind in [:gauge, :observable_gauge] do
    {:gauge,
     %Opentelemetry.Proto.Metrics.V1.Gauge{
       data_points: Enum.map(metric.datapoints, &encode_number_data_point/1)
     }}
  end

  defp encode_metric_data(%{kind: :histogram} = metric) do
    {:histogram,
     %Opentelemetry.Proto.Metrics.V1.Histogram{
       data_points: Enum.map(metric.datapoints, &encode_histogram_data_point/1),
       aggregation_temporality: encode_temporality(metric.temporality)
     }}
  end

  @spec encode_number_data_point(dp :: map()) ::
          Opentelemetry.Proto.Metrics.V1.NumberDataPoint.t()
  defp encode_number_data_point(dp) do
    %Opentelemetry.Proto.Metrics.V1.NumberDataPoint{
      attributes: encode_attributes(dp.attributes),
      start_time_unix_nano: dp.start_time,
      time_unix_nano: dp.time,
      value: encode_number_value(dp.value),
      exemplars: encode_metric_exemplars(Map.get(dp, :exemplars, []))
    }
  end

  @spec encode_histogram_data_point(dp :: map()) ::
          Opentelemetry.Proto.Metrics.V1.HistogramDataPoint.t()
  defp encode_histogram_data_point(dp) do
    histogram = dp.value

    %Opentelemetry.Proto.Metrics.V1.HistogramDataPoint{
      attributes: encode_attributes(dp.attributes),
      start_time_unix_nano: dp.start_time,
      time_unix_nano: dp.time,
      count: histogram.count,
      sum: histogram.sum + 0.0,
      bucket_counts: histogram.bucket_counts,
      explicit_bounds: Enum.map(histogram.boundaries, &(&1 + 0.0)),
      min: encode_optional_double(histogram.min),
      max: encode_optional_double(histogram.max),
      exemplars: encode_metric_exemplars(Map.get(dp, :exemplars, []))
    }
  end

  @spec encode_number_value(value :: number()) ::
          {:as_int, integer()} | {:as_double, float()}
  defp encode_number_value(value) when is_integer(value), do: {:as_int, value}
  defp encode_number_value(value) when is_float(value), do: {:as_double, value}
  defp encode_number_value(value), do: {:as_double, value + 0.0}

  @spec encode_optional_double(value :: number() | :unset) :: float() | nil
  defp encode_optional_double(:unset), do: nil
  defp encode_optional_double(value), do: value + 0.0

  @spec encode_temporality(temporality :: atom() | nil) ::
          Opentelemetry.Proto.Metrics.V1.AggregationTemporality.t()
  defp encode_temporality(:delta), do: :AGGREGATION_TEMPORALITY_DELTA
  defp encode_temporality(:cumulative), do: :AGGREGATION_TEMPORALITY_CUMULATIVE
  defp encode_temporality(_), do: :AGGREGATION_TEMPORALITY_UNSPECIFIED

  @spec encode_metric_exemplars(exemplars :: [Otel.SDK.Metrics.Exemplar.t()]) ::
          [Opentelemetry.Proto.Metrics.V1.Exemplar.t()]
  defp encode_metric_exemplars(exemplars) do
    Enum.map(exemplars, &encode_metric_exemplar/1)
  end

  @spec encode_metric_exemplar(exemplar :: Otel.SDK.Metrics.Exemplar.t()) ::
          Opentelemetry.Proto.Metrics.V1.Exemplar.t()
  defp encode_metric_exemplar(exemplar) do
    %Opentelemetry.Proto.Metrics.V1.Exemplar{
      filtered_attributes: encode_attributes(exemplar.filtered_attributes),
      time_unix_nano: exemplar.time,
      value: encode_number_value(exemplar.value),
      span_id: encode_optional_span_id(exemplar.span_id),
      trace_id: encode_optional_trace_id(exemplar.trace_id)
    }
  end

  @spec encode_optional_trace_id(trace_id :: Otel.API.Trace.TraceId.t() | nil) :: binary()
  defp encode_optional_trace_id(nil), do: <<>>
  defp encode_optional_trace_id(%Otel.API.Trace.TraceId{bytes: bytes}), do: bytes

  @spec encode_optional_span_id(span_id :: Otel.API.Trace.SpanId.t() | nil) :: binary()
  defp encode_optional_span_id(nil), do: <<>>
  defp encode_optional_span_id(%Otel.API.Trace.SpanId{bytes: bytes}), do: bytes

  # --- Logs ---

  @doc """
  Encodes a list of log records into an
  ExportLogsServiceRequest protobuf binary.
  """
  @spec encode_logs(log_records :: [map()]) :: binary()
  def encode_logs(log_records) do
    resource_logs = build_resource_logs(log_records)

    %Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest{
      resource_logs: resource_logs
    }
    |> Protobuf.encode()
  end

  @spec build_resource_logs(log_records :: [map()]) ::
          [Opentelemetry.Proto.Logs.V1.ResourceLogs.t()]
  defp build_resource_logs(log_records) do
    log_records
    |> Enum.group_by(& &1.resource)
    |> Enum.map(fn {resource, resource_group} ->
      %Opentelemetry.Proto.Logs.V1.ResourceLogs{
        resource: encode_resource(resource),
        scope_logs: group_logs_by_scope(resource_group),
        schema_url: resource.schema_url
      }
    end)
  end

  @spec group_logs_by_scope(log_records :: [map()]) ::
          [Opentelemetry.Proto.Logs.V1.ScopeLogs.t()]
  defp group_logs_by_scope(log_records) do
    log_records
    |> Enum.group_by(& &1.scope)
    |> Enum.map(fn {scope, scope_group} ->
      %Opentelemetry.Proto.Logs.V1.ScopeLogs{
        scope: encode_scope(scope),
        log_records: Enum.map(scope_group, &encode_log_record/1),
        schema_url: scope_schema_url(scope)
      }
    end)
  end

  @spec encode_log_record(record :: map()) :: Opentelemetry.Proto.Logs.V1.LogRecord.t()
  defp encode_log_record(record) do
    %Opentelemetry.Proto.Logs.V1.LogRecord{
      time_unix_nano: record.timestamp || 0,
      observed_time_unix_nano: record.observed_timestamp || 0,
      severity_number: encode_severity_number(record.severity_number),
      severity_text: record.severity_text || "",
      body: encode_log_body(record.body),
      attributes: encode_attributes(record.attributes || []),
      dropped_attributes_count: Map.get(record, :dropped_attributes_count, 0),
      trace_id: encode_log_trace_id(record.trace_id),
      span_id: encode_log_span_id(record.span_id),
      flags: Map.get(record, :trace_flags, 0),
      event_name: record.event_name || ""
    }
  end

  @spec encode_severity_number(severity :: integer() | nil) ::
          Opentelemetry.Proto.Logs.V1.SeverityNumber.t()
  defp encode_severity_number(nil), do: :SEVERITY_NUMBER_UNSPECIFIED
  defp encode_severity_number(n) when is_integer(n) and n in 1..24, do: n
  defp encode_severity_number(_), do: :SEVERITY_NUMBER_UNSPECIFIED

  @spec encode_log_body(body :: Otel.API.Common.AnyValue.t() | nil) ::
          Opentelemetry.Proto.Common.V1.AnyValue.t() | nil
  defp encode_log_body(nil), do: nil
  defp encode_log_body(%Otel.API.Common.AnyValue{} = body), do: encode_any_value(body)

  @spec encode_log_trace_id(trace_id :: Otel.API.Trace.TraceId.t() | nil) :: binary()
  defp encode_log_trace_id(nil), do: <<>>

  defp encode_log_trace_id(%Otel.API.Trace.TraceId{} = trace_id) do
    if Otel.API.Trace.TraceId.valid?(trace_id), do: trace_id.bytes, else: <<>>
  end

  @spec encode_log_span_id(span_id :: Otel.API.Trace.SpanId.t() | nil) :: binary()
  defp encode_log_span_id(nil), do: <<>>

  defp encode_log_span_id(%Otel.API.Trace.SpanId{} = span_id) do
    if Otel.API.Trace.SpanId.valid?(span_id), do: span_id.bytes, else: <<>>
  end

  # --- Helpers ---

  @spec encode_trace_id(trace_id :: Otel.API.Trace.TraceId.t()) :: <<_::128>>
  defp encode_trace_id(%Otel.API.Trace.TraceId{bytes: bytes}), do: bytes

  @spec encode_span_id(span_id :: Otel.API.Trace.SpanId.t()) :: <<_::64>>
  defp encode_span_id(%Otel.API.Trace.SpanId{bytes: bytes}), do: bytes

  @spec encode_parent_span_id(span_id :: Otel.API.Trace.SpanId.t() | nil) :: binary()
  defp encode_parent_span_id(nil), do: <<>>
  defp encode_parent_span_id(%Otel.API.Trace.SpanId{bytes: bytes}), do: bytes

  @spec encode_span_kind(kind :: atom()) :: Opentelemetry.Proto.Trace.V1.Span.SpanKind.t()
  defp encode_span_kind(:internal), do: :SPAN_KIND_INTERNAL
  defp encode_span_kind(:server), do: :SPAN_KIND_SERVER
  defp encode_span_kind(:client), do: :SPAN_KIND_CLIENT
  defp encode_span_kind(:producer), do: :SPAN_KIND_PRODUCER
  defp encode_span_kind(:consumer), do: :SPAN_KIND_CONSUMER
  defp encode_span_kind(_kind), do: :SPAN_KIND_UNSPECIFIED
end
