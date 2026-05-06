defmodule Otel.OTLP.Encoder do
  @moduledoc false

  @doc """
  Encodes a list of SDK spans into an ExportTraceServiceRequest
  protobuf binary. Resource is read from each span's `resource`
  field and used to group records into ResourceSpans envelopes
  — matching the encode_logs/1 and encode_metrics/1 patterns.
  """
  @spec encode_traces(spans :: [Otel.Trace.Span.t()]) :: binary()
  def encode_traces(spans) do
    resource_spans = build_resource_spans(spans)

    %Opentelemetry.Proto.Collector.Trace.V1.ExportTraceServiceRequest{
      resource_spans: resource_spans
    }
    |> Protobuf.encode()
  end

  @spec build_resource_spans(spans :: [Otel.Trace.Span.t()]) ::
          [Opentelemetry.Proto.Trace.V1.ResourceSpans.t()]
  defp build_resource_spans(spans) do
    spans
    |> Enum.group_by(& &1.resource)
    |> Enum.map(fn {resource, resource_group} ->
      %Opentelemetry.Proto.Trace.V1.ResourceSpans{
        resource: encode_resource(resource),
        scope_spans: group_by_scope(resource_group),
        schema_url: resource.schema_url
      }
    end)
  end

  @spec group_by_scope(spans :: [Otel.Trace.Span.t()]) ::
          [Opentelemetry.Proto.Trace.V1.ScopeSpans.t()]
  defp group_by_scope(spans) do
    spans
    |> Enum.group_by(& &1.instrumentation_scope)
    |> Enum.map(fn {scope, scope_spans} ->
      %Opentelemetry.Proto.Trace.V1.ScopeSpans{
        scope: encode_scope(scope),
        spans: Enum.map(scope_spans, &encode_span/1),
        schema_url: scope.schema_url
      }
    end)
  end

  # --- Resource ---

  @spec encode_resource(resource :: Otel.Resource.t()) ::
          Opentelemetry.Proto.Resource.V1.Resource.t()
  defp encode_resource(resource) do
    %Opentelemetry.Proto.Resource.V1.Resource{
      attributes: encode_attributes(resource.attributes)
    }
  end

  # --- Scope ---

  @spec encode_scope(scope :: Otel.InstrumentationScope.t()) ::
          Opentelemetry.Proto.Common.V1.InstrumentationScope.t()
  defp encode_scope(%Otel.InstrumentationScope{} = scope) do
    %Opentelemetry.Proto.Common.V1.InstrumentationScope{
      name: scope.name,
      version: scope.version,
      attributes: encode_attributes(scope.attributes)
    }
  end

  # --- Span ---

  @spec encode_span(span :: Otel.Trace.Span.t()) ::
          Opentelemetry.Proto.Trace.V1.Span.t()
  defp encode_span(%Otel.Trace.Span{} = span) do
    %Opentelemetry.Proto.Trace.V1.Span{
      trace_id: encode_id(span.trace_id, 16),
      span_id: encode_id(span.span_id, 8),
      parent_span_id: encode_parent_span_id(span.parent_span_id),
      trace_state: Otel.Trace.TraceState.encode(span.tracestate),
      name: span.name,
      kind: encode_span_kind(span.kind),
      start_time_unix_nano: span.start_time,
      end_time_unix_nano: span.end_time,
      attributes: encode_attributes(span.attributes),
      dropped_attributes_count: span.dropped_attributes_count,
      events: Enum.map(span.events, &encode_event/1),
      dropped_events_count: span.dropped_events_count,
      links: Enum.map(span.links, &encode_link/1),
      dropped_links_count: span.dropped_links_count,
      status: encode_status(span.status),
      flags: span.trace_flags
    }
  end

  # --- Event ---

  @spec encode_event(event :: Otel.Trace.Event.t()) ::
          Opentelemetry.Proto.Trace.V1.Span.Event.t()
  defp encode_event(%Otel.Trace.Event{} = event) do
    %Opentelemetry.Proto.Trace.V1.Span.Event{
      time_unix_nano: event.timestamp,
      name: event.name,
      attributes: encode_attributes(event.attributes),
      dropped_attributes_count: event.dropped_attributes_count
    }
  end

  # --- Link ---

  @spec encode_link(link :: Otel.Trace.Link.t()) ::
          Opentelemetry.Proto.Trace.V1.Span.Link.t()
  defp encode_link(%Otel.Trace.Link{} = link) do
    %Opentelemetry.Proto.Trace.V1.Span.Link{
      trace_id: encode_id(link.context.trace_id, 16),
      span_id: encode_id(link.context.span_id, 8),
      trace_state: Otel.Trace.TraceState.encode(link.context.tracestate),
      attributes: encode_attributes(link.attributes),
      dropped_attributes_count: link.dropped_attributes_count
    }
  end

  # --- Status ---

  @spec encode_status(status :: Otel.Trace.Status.t()) ::
          Opentelemetry.Proto.Trace.V1.Status.t() | nil
  defp encode_status(%Otel.Trace.Status{code: :unset}), do: nil

  defp encode_status(%Otel.Trace.Status{code: :ok}) do
    %Opentelemetry.Proto.Trace.V1.Status{code: :STATUS_CODE_OK, message: ""}
  end

  defp encode_status(%Otel.Trace.Status{code: :error, description: message}) do
    %Opentelemetry.Proto.Trace.V1.Status{code: :STATUS_CODE_ERROR, message: message}
  end

  # --- Attributes ---

  @spec encode_attributes(attrs :: map()) :: [Opentelemetry.Proto.Common.V1.KeyValue.t()]
  defp encode_attributes(attrs) when is_map(attrs) do
    Enum.map(attrs, fn {key, value} ->
      %Opentelemetry.Proto.Common.V1.KeyValue{
        key: key,
        value: encode_any_value(value)
      }
    end)
  end

  # Each clause maps one shape of `Otel.Common.Types.primitive_any/0`
  # to its OTLP `AnyValue` oneof case. Invalid types (atoms other
  # than booleans, tuples that aren't `{:bytes, _}`, refs, pids,
  # etc.) are not in the type contract and crash with
  # `FunctionClauseError` — happy-path policy: invalid input is a
  # caller bug, not encoder responsibility to silently coerce.
  @spec encode_any_value(value :: term()) :: Opentelemetry.Proto.Common.V1.AnyValue.t()
  # `nil` → empty `AnyValue` (oneof unset). Spec
  # `common/README.md` L50-L51 admits null as a valid AnyValue
  # in languages that support it; L67-L68 MUST that null values
  # within arrays MUST be preserved as-is. `%AnyValue{}` is the
  # OTLP wire-level representation of "this AnyValue is empty".
  defp encode_any_value(nil), do: %Opentelemetry.Proto.Common.V1.AnyValue{}

  defp encode_any_value({:bytes, value}) when is_binary(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:bytes_value, value}}
  end

  defp encode_any_value(value) when is_binary(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:string_value, value}}
  end

  # `is_boolean` must precede any `is_atom` — but the latter is
  # absent now, leaving boolean as the only atom shape we accept.
  defp encode_any_value(value) when is_boolean(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:bool_value, value}}
  end

  defp encode_any_value(value) when is_integer(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:int_value, value}}
  end

  defp encode_any_value(value) when is_float(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:double_value, value}}
  end

  defp encode_any_value(value) when is_list(value) do
    array = %Opentelemetry.Proto.Common.V1.ArrayValue{
      values: Enum.map(value, &encode_any_value/1)
    }

    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:array_value, array}}
  end

  defp encode_any_value(value) when is_map(value) do
    kvs =
      Enum.map(value, fn {k, v} ->
        %Opentelemetry.Proto.Common.V1.KeyValue{
          key: to_string(k),
          value: encode_any_value(v)
        }
      end)

    kvlist = %Opentelemetry.Proto.Common.V1.KeyValueList{values: kvs}
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:kvlist_value, kvlist}}
  end

  # --- Metrics ---

  @doc """
  Encodes a list of collected metrics into an
  ExportMetricsServiceRequest protobuf binary.
  """
  @spec encode_metrics(metrics :: [Otel.Metrics.Metric.t()]) :: binary()
  def encode_metrics(metrics) do
    resource_metrics = build_resource_metrics(metrics)

    %Opentelemetry.Proto.Collector.Metrics.V1.ExportMetricsServiceRequest{
      resource_metrics: resource_metrics
    }
    |> Protobuf.encode()
  end

  @spec build_resource_metrics(metrics :: [Otel.Metrics.Metric.t()]) ::
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

  @spec group_metrics_by_scope(metrics :: [Otel.Metrics.Metric.t()]) ::
          [Opentelemetry.Proto.Metrics.V1.ScopeMetrics.t()]
  defp group_metrics_by_scope(metrics) do
    metrics
    |> Enum.group_by(& &1.scope)
    |> Enum.map(fn {scope, scope_group} ->
      %Opentelemetry.Proto.Metrics.V1.ScopeMetrics{
        scope: encode_scope(scope),
        metrics: Enum.map(scope_group, &encode_metric/1),
        schema_url: scope.schema_url
      }
    end)
  end

  @spec encode_metric(metric :: Otel.Metrics.Metric.t()) ::
          Opentelemetry.Proto.Metrics.V1.Metric.t()
  defp encode_metric(metric) do
    %Opentelemetry.Proto.Metrics.V1.Metric{
      name: metric.name,
      description: metric.description,
      unit: metric.unit,
      data: encode_metric_data(metric)
    }
  end

  @spec encode_metric_data(metric :: Otel.Metrics.Metric.t()) ::
          {:sum, Opentelemetry.Proto.Metrics.V1.Sum.t()}
          | {:gauge, Opentelemetry.Proto.Metrics.V1.Gauge.t()}
          | {:histogram, Opentelemetry.Proto.Metrics.V1.Histogram.t()}
  defp encode_metric_data(%{kind: kind} = metric)
       when kind in [:counter, :updown_counter] do
    {:sum,
     %Opentelemetry.Proto.Metrics.V1.Sum{
       data_points: Enum.map(metric.datapoints, &encode_number_data_point/1),
       aggregation_temporality: encode_temporality(metric.temporality),
       is_monotonic: metric.is_monotonic
     }}
  end

  defp encode_metric_data(%{kind: :gauge} = metric) do
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
      exemplars: encode_metric_exemplars(dp.exemplars)
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
      exemplars: encode_metric_exemplars(dp.exemplars)
    }
  end

  @spec encode_number_value(value :: number()) ::
          {:as_int, integer()} | {:as_double, float()}
  defp encode_number_value(value) when is_integer(value), do: {:as_int, value}
  defp encode_number_value(value) when is_float(value), do: {:as_double, value}
  defp encode_number_value(value), do: {:as_double, value + 0.0}

  @spec encode_optional_double(value :: number() | nil) :: float() | nil
  defp encode_optional_double(nil), do: nil
  defp encode_optional_double(value), do: value + 0.0

  @spec encode_temporality(temporality :: atom() | nil) ::
          Opentelemetry.Proto.Metrics.V1.AggregationTemporality.t()
  defp encode_temporality(:delta), do: :AGGREGATION_TEMPORALITY_DELTA
  defp encode_temporality(:cumulative), do: :AGGREGATION_TEMPORALITY_CUMULATIVE
  defp encode_temporality(_), do: :AGGREGATION_TEMPORALITY_UNSPECIFIED

  @spec encode_metric_exemplars(exemplars :: [Otel.Metrics.Exemplar.t()]) ::
          [Opentelemetry.Proto.Metrics.V1.Exemplar.t()]
  defp encode_metric_exemplars(exemplars) do
    Enum.map(exemplars, &encode_metric_exemplar/1)
  end

  @spec encode_metric_exemplar(exemplar :: Otel.Metrics.Exemplar.t()) ::
          Opentelemetry.Proto.Metrics.V1.Exemplar.t()
  defp encode_metric_exemplar(exemplar) do
    %Opentelemetry.Proto.Metrics.V1.Exemplar{
      filtered_attributes: encode_attributes(exemplar.filtered_attributes),
      time_unix_nano: exemplar.time,
      value: encode_number_value(exemplar.value),
      span_id: encode_optional_id(exemplar.span_id, 8),
      trace_id: encode_optional_id(exemplar.trace_id, 16)
    }
  end

  @spec encode_optional_id(id :: non_neg_integer() | nil, byte_size :: pos_integer()) :: binary()
  defp encode_optional_id(nil, _byte_size), do: <<>>
  defp encode_optional_id(id, byte_size), do: <<id::unsigned-integer-size(byte_size * 8)>>

  # --- Logs ---

  @doc """
  Encodes a list of log records into an
  ExportLogsServiceRequest protobuf binary.
  """
  @spec encode_logs(log_records :: [Otel.Logs.LogRecord.t()]) :: binary()
  def encode_logs(log_records) do
    resource_logs = build_resource_logs(log_records)

    %Opentelemetry.Proto.Collector.Logs.V1.ExportLogsServiceRequest{
      resource_logs: resource_logs
    }
    |> Protobuf.encode()
  end

  @spec build_resource_logs(log_records :: [Otel.Logs.LogRecord.t()]) ::
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

  @spec group_logs_by_scope(log_records :: [Otel.Logs.LogRecord.t()]) ::
          [Opentelemetry.Proto.Logs.V1.ScopeLogs.t()]
  defp group_logs_by_scope(log_records) do
    log_records
    |> Enum.group_by(& &1.scope)
    |> Enum.map(fn {scope, scope_group} ->
      %Opentelemetry.Proto.Logs.V1.ScopeLogs{
        scope: encode_scope(scope),
        log_records: Enum.map(scope_group, &encode_log_record/1),
        schema_url: scope.schema_url
      }
    end)
  end

  @spec encode_log_record(record :: Otel.Logs.LogRecord.t()) ::
          Opentelemetry.Proto.Logs.V1.LogRecord.t()
  defp encode_log_record(record) do
    %Opentelemetry.Proto.Logs.V1.LogRecord{
      time_unix_nano: record.timestamp,
      observed_time_unix_nano: record.observed_timestamp,
      severity_number: encode_severity_number(record.severity_number),
      severity_text: record.severity_text,
      body: encode_log_body(record.body),
      attributes: encode_attributes(record.attributes),
      dropped_attributes_count: record.dropped_attributes_count,
      trace_id: encode_optional_id(nonzero_or_nil(record.trace_id), 16),
      span_id: encode_optional_id(nonzero_or_nil(record.span_id), 8),
      flags: record.trace_flags,
      event_name: record.event_name
    }
  end

  @spec encode_severity_number(severity :: non_neg_integer()) ::
          Opentelemetry.Proto.Logs.V1.SeverityNumber.t()
  defp encode_severity_number(0), do: :SEVERITY_NUMBER_UNSPECIFIED
  defp encode_severity_number(n) when is_integer(n) and n in 1..24, do: n

  @spec encode_log_body(body :: term()) :: Opentelemetry.Proto.Common.V1.AnyValue.t() | nil
  defp encode_log_body(nil), do: nil
  defp encode_log_body(body), do: encode_any_value(body)

  @spec nonzero_or_nil(id :: non_neg_integer() | nil) :: non_neg_integer() | nil
  defp nonzero_or_nil(0), do: nil
  defp nonzero_or_nil(id), do: id

  # --- Helpers ---

  @spec encode_id(id :: non_neg_integer(), byte_size :: pos_integer()) :: binary()
  defp encode_id(id, byte_size) do
    <<id::unsigned-integer-size(byte_size * 8)>>
  end

  @spec encode_parent_span_id(span_id :: non_neg_integer() | nil) :: binary()
  defp encode_parent_span_id(nil), do: <<>>
  defp encode_parent_span_id(0), do: <<>>
  defp encode_parent_span_id(span_id), do: encode_id(span_id, 8)

  @spec encode_span_kind(kind :: atom()) :: Opentelemetry.Proto.Trace.V1.Span.SpanKind.t()
  defp encode_span_kind(:internal), do: :SPAN_KIND_INTERNAL
  defp encode_span_kind(:server), do: :SPAN_KIND_SERVER
  defp encode_span_kind(:client), do: :SPAN_KIND_CLIENT
  defp encode_span_kind(:producer), do: :SPAN_KIND_PRODUCER
  defp encode_span_kind(:consumer), do: :SPAN_KIND_CONSUMER
  defp encode_span_kind(_kind), do: :SPAN_KIND_UNSPECIFIED
end
