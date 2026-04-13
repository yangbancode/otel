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

  @spec encode_scope(scope :: Otel.API.Trace.InstrumentationScope.t() | nil) ::
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
      trace_id: encode_id(span.trace_id, 16),
      span_id: encode_id(span.span_id, 8),
      parent_span_id: encode_parent_span_id(span.parent_span_id),
      trace_state: encode_tracestate(span.tracestate),
      name: span.name,
      kind: encode_span_kind(span.kind),
      start_time_unix_nano: span.start_time,
      end_time_unix_nano: span.end_time || 0,
      attributes: encode_attributes(span.attributes),
      events: Enum.map(span.events, &encode_event/1),
      links: Enum.map(span.links, &encode_link/1),
      status: encode_status(span.status),
      flags: span.trace_flags
    }
  end

  # --- Event ---

  @spec encode_event(event :: map()) :: Opentelemetry.Proto.Trace.V1.Span.Event.t()
  defp encode_event(event) do
    %Opentelemetry.Proto.Trace.V1.Span.Event{
      time_unix_nano: event.time,
      name: to_string(event.name),
      attributes: encode_attributes(event.attributes)
    }
  end

  # --- Link ---

  @spec encode_link(link :: {Otel.API.Trace.SpanContext.t(), map()}) ::
          Opentelemetry.Proto.Trace.V1.Span.Link.t()
  defp encode_link({span_ctx, attrs}) do
    %Opentelemetry.Proto.Trace.V1.Span.Link{
      trace_id: encode_id(span_ctx.trace_id, 16),
      span_id: encode_id(span_ctx.span_id, 8),
      trace_state: Otel.API.Trace.TraceState.encode(span_ctx.tracestate),
      attributes: encode_attributes(attrs)
    }
  end

  # --- Status ---

  @spec encode_status(status :: {atom(), String.t()} | nil) ::
          Opentelemetry.Proto.Trace.V1.Status.t() | nil
  defp encode_status(nil), do: nil

  defp encode_status({:ok, _message}) do
    %Opentelemetry.Proto.Trace.V1.Status{
      code: :STATUS_CODE_OK,
      message: ""
    }
  end

  defp encode_status({:error, message}) do
    %Opentelemetry.Proto.Trace.V1.Status{
      code: :STATUS_CODE_ERROR,
      message: message
    }
  end

  # --- Attributes ---

  @spec encode_attributes(attrs :: map()) :: [Opentelemetry.Proto.Common.V1.KeyValue.t()]
  defp encode_attributes(attrs) when is_map(attrs) do
    Enum.map(attrs, fn {key, value} ->
      %Opentelemetry.Proto.Common.V1.KeyValue{
        key: to_string(key),
        value: encode_any_value(value)
      }
    end)
  end

  @spec encode_any_value(value :: term()) :: Opentelemetry.Proto.Common.V1.AnyValue.t()
  defp encode_any_value(value) when is_binary(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:string_value, value}}
  end

  defp encode_any_value(value) when is_integer(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:int_value, value}}
  end

  defp encode_any_value(value) when is_float(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:double_value, value}}
  end

  defp encode_any_value(value) when is_boolean(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:bool_value, value}}
  end

  defp encode_any_value(value) when is_atom(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:string_value, Atom.to_string(value)}}
  end

  defp encode_any_value(value) when is_list(value) do
    array = %Opentelemetry.Proto.Common.V1.ArrayValue{
      values: Enum.map(value, &encode_any_value/1)
    }

    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:array_value, array}}
  end

  defp encode_any_value(value) do
    %Opentelemetry.Proto.Common.V1.AnyValue{value: {:string_value, inspect(value)}}
  end

  # --- Helpers ---

  @spec encode_id(id :: non_neg_integer(), byte_size :: pos_integer()) :: binary()
  defp encode_id(id, byte_size) do
    <<id::unsigned-integer-size(byte_size * 8)>>
  end

  @spec encode_parent_span_id(span_id :: non_neg_integer() | nil) :: binary()
  defp encode_parent_span_id(nil), do: <<>>
  defp encode_parent_span_id(0), do: <<>>
  defp encode_parent_span_id(span_id), do: encode_id(span_id, 8)

  @spec encode_tracestate(tracestate :: Otel.API.Trace.TraceState.t()) :: String.t()
  defp encode_tracestate(tracestate) do
    Otel.API.Trace.TraceState.encode(tracestate)
  end

  @spec encode_span_kind(kind :: atom()) :: Opentelemetry.Proto.Trace.V1.Span.SpanKind.t()
  defp encode_span_kind(:internal), do: :SPAN_KIND_INTERNAL
  defp encode_span_kind(:server), do: :SPAN_KIND_SERVER
  defp encode_span_kind(:client), do: :SPAN_KIND_CLIENT
  defp encode_span_kind(:producer), do: :SPAN_KIND_PRODUCER
  defp encode_span_kind(:consumer), do: :SPAN_KIND_CONSUMER
  defp encode_span_kind(_), do: :SPAN_KIND_UNSPECIFIED
end
