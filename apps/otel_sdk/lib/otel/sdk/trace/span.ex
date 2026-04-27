defmodule Otel.SDK.Trace.Span do
  @moduledoc """
  SDK implementation of the `Otel.API.Trace.Span` behaviour
  (`trace/sdk.md` §Span L692-L944) — data + lifecycle
  operations.

  Holds all span data during its lifecycle. Creation is a pure
  operation; all mutating operations read/write the span in ETS via
  `SpanStorage` and are no-ops when the span is not in ETS (already
  ended or dropped), satisfying spec `trace/api.md` L478-L481
  (an ended span SHOULD become non-recording).

  Registered as the global span module on SDK application start;
  the API layer's `Otel.API.Trace.Span` dispatches to the functions
  defined here via the `Otel.API.Trace.Span` behaviour.

  All functions are safe for concurrent use — every mutation
  goes through `:ets.update_element` / `:ets.insert` against
  the public `SpanStorage` table, satisfying spec L883
  (*"Span — all methods MUST be documented that
  implementations need to be safe for concurrent use by
  default."*).

  ## Public API

  | Callback | Role |
  |---|---|
  | `start_span/6` | **SDK** (lifecycle) — sampler + id-generator + storage insert |
  | `recording?/1`, `set_attribute/3`, `set_attributes/2`, `add_event/2`, `add_link/2`, `set_status/2`, `update_name/2`, `record_exception/4`, `end_span/2` | **SDK** (OTel API MUST/SHOULD) — `trace/api.md` §Span operations L449-L705 |

  ## Design notes

  ### Span-resident SpanLimits and processors_key

  `span_limits` is stored as a field on each span rather than
  threaded through call arguments or fetched from a global
  registry, so `set_attribute/3`, `add_event/2`, etc. operate
  on the span fetched from `SpanStorage` without a second
  lookup.

  `processors_key` is the `:persistent_term` key under which
  the TracerProvider published the projected processor list.
  `end_span/2` reads from that key fresh — so if a processor
  crashed between start and end, the TracerProvider's EXIT
  handler has already removed it from the persistent_term
  list and `on_end/2` skips it. Mirrors the `Logger.emit`
  pattern (`Otel.SDK.Logs.Logger`).

  This diverges from `opentelemetry-erlang`, which threads
  limits through `otel_span_utils` per call
  (`opentelemetry/src/otel_span_utils.erl`) and stores
  processors on the `span_ctx.span_sdk` tuple
  (`otel_span_ets.erl` L60, L77).

  ### Dropped-count tracking

  Proto `Span` fields 10 (`dropped_attributes_count`), 12
  (`dropped_events_count`), and 14 (`dropped_links_count`)
  are tracked on this struct, plus the per-Event and per-Link
  `dropped_attributes_count`. Spec `trace/sdk.md` L260-L262
  *"Counts for attributes, events and links dropped due to
  collection limits MUST be available for exporters to
  report."* The counters are incremented by `start_span/6`,
  `set_attribute/3`, `set_attributes/2`, `add_event/2`, and
  `add_link/2` whenever the corresponding span_limits cap
  causes a discard. Value-length truncation is **not**
  counted as a drop (spec common L262-L274 — truncation
  preserves the attribute, only its value shrinks).

  ### `is_recording`, `instrumentation_scope` on the span

  Both fields exist on the span (lines 34-35) but neither
  appears in the proto `Span` message. They mirror erlang's
  `otel_span.hrl` (L60, L62) — `is_recording` is an
  implementation optimization not propagated to wire format,
  and `instrumentation_scope` is held on the span for
  grouping into `ScopeSpans` at export time.

  ## References

  - OTel Trace SDK §Span: `opentelemetry-specification/specification/trace/sdk.md` L692-L944
  - OTel Trace API §Span: `opentelemetry-specification/specification/trace/api.md` L449-L705
  - OTLP proto Span: `opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto`
  """

  use Otel.API.Common.Types

  @behaviour Otel.API.Trace.Span

  @type t :: %__MODULE__{
          trace_id: Otel.API.Trace.TraceId.t(),
          span_id: Otel.API.Trace.SpanId.t(),
          tracestate: Otel.API.Trace.TraceState.t(),
          parent_span_id: Otel.API.Trace.SpanId.t() | nil,
          parent_span_is_remote: boolean() | nil,
          name: String.t(),
          kind: Otel.API.Trace.SpanKind.t(),
          start_time: non_neg_integer(),
          end_time: non_neg_integer() | nil,
          attributes: %{String.t() => primitive_any()},
          dropped_attributes_count: non_neg_integer(),
          events: [Otel.API.Trace.Event.t()],
          dropped_events_count: non_neg_integer(),
          links: [Otel.API.Trace.Link.t()],
          dropped_links_count: non_neg_integer(),
          status: Otel.API.Trace.Status.t(),
          trace_flags: Otel.API.Trace.SpanContext.trace_flags(),
          is_recording: boolean(),
          instrumentation_scope: Otel.API.InstrumentationScope.t() | nil,
          span_limits: Otel.SDK.Trace.SpanLimits.t(),
          processors_key: term() | nil
        }

  defstruct [
    :trace_id,
    :span_id,
    :parent_span_id,
    :parent_span_is_remote,
    :name,
    :end_time,
    :instrumentation_scope,
    :processors_key,
    tracestate: Otel.API.Trace.TraceState.new(),
    kind: :internal,
    start_time: 0,
    attributes: %{},
    dropped_attributes_count: 0,
    events: [],
    dropped_events_count: 0,
    links: [],
    dropped_links_count: 0,
    status: %Otel.API.Trace.Status{},
    trace_flags: 0,
    is_recording: true,
    span_limits: %Otel.SDK.Trace.SpanLimits{}
  ]

  # --- Creation ---

  @doc """
  Creates a span following the SDK creation flow (spec L339).

  Returns `{span_ctx, span | nil}` where span is nil for dropped spans.
  """
  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          name :: String.t(),
          sampler :: Otel.SDK.Trace.Sampler.t(),
          id_generator :: module(),
          span_limits :: Otel.SDK.Trace.SpanLimits.t(),
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: {Otel.API.Trace.SpanContext.t(), t() | nil}
  def start_span(ctx, name, sampler, id_generator, span_limits, opts) do
    kind = Keyword.get(opts, :kind, :internal)
    attributes = Keyword.get(opts, :attributes, %{})
    links = Keyword.get(opts, :links, [])
    start_time = Keyword.get(opts, :start_time, System.system_time(:nanosecond))

    {span_ctx, parent_span_id, parent_is_remote} = new_span_ctx(ctx, id_generator, opts)

    trace_id = span_ctx.trace_id
    span_id = span_ctx.span_id

    {trace_flags, is_recording, sampler_attributes, tracestate} =
      sample(ctx, sampler, trace_id, links, name, kind, attributes)

    span_ctx = %Otel.API.Trace.SpanContext{
      span_ctx
      | trace_flags: trace_flags,
        tracestate: tracestate
    }

    if is_recording do
      {merged_attributes, dropped_attributes_count} =
        attributes
        |> Map.merge(sampler_attributes)
        |> apply_attribute_limits(
          span_limits.attribute_count_limit,
          span_limits.attribute_value_length_limit
        )

      limited_links =
        links
        |> Enum.take(span_limits.link_count_limit)
        |> Enum.map(fn %Otel.API.Trace.Link{} = link ->
          {link_attrs, link_dropped} =
            apply_attribute_limits(
              link.attributes,
              span_limits.attribute_per_link_limit,
              span_limits.attribute_value_length_limit
            )

          %{
            link
            | attributes: link_attrs,
              dropped_attributes_count: link.dropped_attributes_count + link_dropped
          }
        end)

      dropped_links_count = max(length(links) - span_limits.link_count_limit, 0)

      span = %__MODULE__{
        trace_id: trace_id,
        span_id: span_id,
        tracestate: tracestate,
        parent_span_id: parent_span_id,
        parent_span_is_remote: parent_is_remote,
        name: name,
        kind: kind,
        start_time: start_time,
        attributes: merged_attributes,
        dropped_attributes_count: dropped_attributes_count,
        events: [],
        dropped_events_count: 0,
        links: limited_links,
        dropped_links_count: dropped_links_count,
        trace_flags: trace_flags,
        is_recording: true
      }

      {span_ctx, span}
    else
      {span_ctx, nil}
    end
  end

  # --- Lifecycle operations (ETS-backed) ---

  @doc """
  Returns whether the span is currently recording.
  """
  @impl true
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.API.Trace.SpanContext{span_id: span_id}) do
    Otel.SDK.Trace.SpanStorage.get(span_id) != nil
  end

  @doc """
  Sets a single attribute on the span.
  """
  @impl true
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t(),
          value :: primitive_any()
        ) :: :ok
  def set_attribute(%Otel.API.Trace.SpanContext{span_id: span_id}, key, value) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits
        value = truncate_value(value, limits.attribute_value_length_limit)

        {attributes, drop_inc} =
          put_attribute(span.attributes, key, value, limits.attribute_count_limit)

        Otel.SDK.Trace.SpanStorage.insert(%{
          span
          | attributes: attributes,
            dropped_attributes_count: span.dropped_attributes_count + drop_inc
        })

        :ok
    end
  end

  @doc """
  Sets multiple attributes on the span.
  """
  @impl true
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes ::
            %{String.t() => primitive_any()}
            | [{String.t(), primitive_any()}]
        ) :: :ok
  def set_attributes(%Otel.API.Trace.SpanContext{span_id: span_id}, new_attributes) do
    new_attributes =
      if is_list(new_attributes), do: Map.new(new_attributes), else: new_attributes

    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        {attributes, drop_inc} =
          merge_attributes(new_attributes, span.attributes, span.span_limits)

        Otel.SDK.Trace.SpanStorage.insert(%{
          span
          | attributes: attributes,
            dropped_attributes_count: span.dropped_attributes_count + drop_inc
        })

        :ok
    end
  end

  @doc """
  Adds an event to the span.
  """
  @impl true
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          event :: Otel.API.Trace.Event.t()
        ) :: :ok
  def add_event(
        %Otel.API.Trace.SpanContext{span_id: span_id},
        %Otel.API.Trace.Event{} = event
      ) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits

        if length(span.events) < limits.event_count_limit do
          {limited_attributes, attr_drop_inc} =
            apply_attribute_limits(
              event.attributes,
              limits.attribute_per_event_limit,
              limits.attribute_value_length_limit
            )

          limited_event = %{
            event
            | attributes: limited_attributes,
              dropped_attributes_count: event.dropped_attributes_count + attr_drop_inc
          }

          Otel.SDK.Trace.SpanStorage.insert(%{span | events: span.events ++ [limited_event]})
        else
          Otel.SDK.Trace.SpanStorage.insert(%{
            span
            | dropped_events_count: span.dropped_events_count + 1
          })
        end

        :ok
    end
  end

  @doc """
  Adds a link to another span after creation.
  """
  @impl true
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          link :: Otel.API.Trace.Link.t()
        ) :: :ok
  def add_link(
        %Otel.API.Trace.SpanContext{span_id: span_id},
        %Otel.API.Trace.Link{} = link
      ) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits

        if length(span.links) < limits.link_count_limit do
          {limited_attributes, attr_drop_inc} =
            apply_attribute_limits(
              link.attributes,
              limits.attribute_per_link_limit,
              limits.attribute_value_length_limit
            )

          limited_link = %{
            link
            | attributes: limited_attributes,
              dropped_attributes_count: link.dropped_attributes_count + attr_drop_inc
          }

          Otel.SDK.Trace.SpanStorage.insert(%{span | links: span.links ++ [limited_link]})
        else
          Otel.SDK.Trace.SpanStorage.insert(%{
            span
            | dropped_links_count: span.dropped_links_count + 1
          })
        end

        :ok
    end
  end

  @doc """
  Sets the status of the span.

  Status priority: Ok > Error > Unset. Once set to :ok, status is final.
  Setting :unset is always ignored.
  """
  @impl true
  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          status :: Otel.API.Trace.Status.t()
        ) :: :ok
  def set_status(
        %Otel.API.Trace.SpanContext{span_id: span_id},
        %Otel.API.Trace.Status{} = status
      ) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        updated = apply_set_status(span, status)
        Otel.SDK.Trace.SpanStorage.insert(updated)
        :ok
    end
  end

  @doc """
  Updates the name of the span.
  """
  @impl true
  @spec update_name(span_ctx :: Otel.API.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(%Otel.API.Trace.SpanContext{span_id: span_id}, name) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        Otel.SDK.Trace.SpanStorage.insert(%{span | name: name})
        :ok
    end
  end

  @doc """
  Ends the span.

  Removes the span from ETS, sets end_time and is_recording=false,
  then calls on_end on all processors.
  """
  @impl true
  @spec end_span(span_ctx :: Otel.API.Trace.SpanContext.t(), timestamp :: non_neg_integer()) ::
          :ok
  def end_span(%Otel.API.Trace.SpanContext{span_id: span_id}, timestamp) do
    case Otel.SDK.Trace.SpanStorage.take(span_id) do
      nil ->
        :ok

      span ->
        end_time = timestamp || System.system_time(:nanosecond)
        ended_span = %{span | end_time: end_time, is_recording: false}
        # Read the processor list fresh from `:persistent_term`
        # so a processor that crashed between start and end is
        # skipped rather than receiving on_end on a dead pid.
        processors =
          if span.processors_key, do: :persistent_term.get(span.processors_key, []), else: []

        run_on_end(ended_span, processors)
        :ok
    end
  end

  @doc """
  Records an exception as an event on the span.
  """
  @impl true
  @spec record_exception(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: %{String.t() => primitive_any()}
        ) :: :ok
  def record_exception(span_ctx, exception, stacktrace, attributes) do
    exception_attributes =
      Map.merge(
        %{
          "exception.type" => exception_type(exception),
          "exception.message" => Exception.message(exception),
          "exception.stacktrace" => Exception.format_stacktrace(stacktrace)
        },
        attributes
      )

    add_event(span_ctx, Otel.API.Trace.Event.new("exception", exception_attributes))
  end

  # --- Private helpers ---

  @spec new_span_ctx(
          ctx :: Otel.API.Ctx.t(),
          id_generator :: module(),
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: {Otel.API.Trace.SpanContext.t(), Otel.API.Trace.SpanId.t() | nil, boolean() | nil}
  defp new_span_ctx(ctx, id_generator, opts) do
    parent = Otel.API.Trace.current_span(ctx)
    is_root = Keyword.get(opts, :is_root, false)

    if is_root or not Otel.API.Trace.SpanContext.valid?(parent) do
      root_span_ctx(id_generator)
    else
      child_span_ctx(parent, id_generator)
    end
  end

  @spec child_span_ctx(
          parent :: Otel.API.Trace.SpanContext.t(),
          id_generator :: module()
        ) :: {Otel.API.Trace.SpanContext.t(), Otel.API.Trace.SpanId.t(), boolean()}
  defp child_span_ctx(parent, id_generator) do
    span_id = id_generator.generate_span_id()

    {
      %Otel.API.Trace.SpanContext{
        trace_id: parent.trace_id,
        span_id: span_id,
        tracestate: parent.tracestate,
        is_remote: false
      },
      parent.span_id,
      parent.is_remote
    }
  end

  @spec root_span_ctx(id_generator :: module()) ::
          {Otel.API.Trace.SpanContext.t(), nil, nil}
  defp root_span_ctx(id_generator) do
    trace_id = id_generator.generate_trace_id()
    span_id = id_generator.generate_span_id()

    {
      %Otel.API.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        is_remote: false
      },
      nil,
      nil
    }
  end

  @spec sample(
          ctx :: Otel.API.Ctx.t(),
          sampler :: Otel.SDK.Trace.Sampler.t(),
          trace_id :: Otel.API.Trace.TraceId.t(),
          links :: [Otel.API.Trace.Link.t()],
          name :: String.t(),
          kind :: Otel.API.Trace.SpanKind.t(),
          attributes :: %{String.t() => primitive_any()}
        ) ::
          {Otel.API.Trace.SpanContext.trace_flags(), boolean(), %{String.t() => primitive_any()},
           Otel.API.Trace.TraceState.t()}
  defp sample(ctx, sampler, trace_id, links, name, kind, attributes) do
    {decision, new_attributes, tracestate} =
      Otel.SDK.Trace.Sampler.should_sample(
        sampler,
        ctx,
        trace_id,
        links,
        name,
        kind,
        attributes
      )

    case decision do
      :drop -> {0, false, new_attributes, tracestate}
      :record_only -> {0, true, new_attributes, tracestate}
      :record_and_sample -> {1, true, new_attributes, tracestate}
    end
  end

  @spec merge_attributes(
          new_attributes :: %{String.t() => primitive_any()},
          existing :: %{String.t() => primitive_any()},
          limits :: Otel.SDK.Trace.SpanLimits.t()
        ) :: {%{String.t() => primitive_any()}, non_neg_integer()}
  defp merge_attributes(new_attributes, existing, limits) do
    Enum.reduce(new_attributes, {existing, 0}, fn {key, value}, {acc, dropped} ->
      {acc, drop_inc} =
        put_attribute(
          acc,
          key,
          truncate_value(value, limits.attribute_value_length_limit),
          limits.attribute_count_limit
        )

      {acc, dropped + drop_inc}
    end)
  end

  @spec put_attribute(
          attributes :: %{String.t() => primitive_any()},
          key :: String.t(),
          value :: primitive_any(),
          count_limit :: pos_integer()
        ) :: {%{String.t() => primitive_any()}, 0 | 1}
  defp put_attribute(attributes, key, value, count_limit) do
    cond do
      Map.has_key?(attributes, key) -> {Map.put(attributes, key, value), 0}
      map_size(attributes) < count_limit -> {Map.put(attributes, key, value), 0}
      true -> {attributes, 1}
    end
  end

  @spec apply_set_status(
          span :: t(),
          status :: Otel.API.Trace.Status.t()
        ) :: t()
  defp apply_set_status(span, %Otel.API.Trace.Status{code: :unset}), do: span

  defp apply_set_status(%{status: %Otel.API.Trace.Status{code: :ok}} = span, _status), do: span

  defp apply_set_status(span, %Otel.API.Trace.Status{code: :ok}) do
    %{span | status: %Otel.API.Trace.Status{code: :ok, description: ""}}
  end

  defp apply_set_status(span, %Otel.API.Trace.Status{code: :error, description: description}) do
    %{span | status: %Otel.API.Trace.Status{code: :error, description: description}}
  end

  @spec run_on_end(
          span :: t(),
          processors :: [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
        ) :: :ok
  defp run_on_end(span, processors) do
    Enum.each(processors, fn {processor, processor_config} ->
      processor.on_end(span, processor_config)
    end)
  end

  @spec apply_attribute_limits(
          attributes :: %{String.t() => primitive_any()},
          count_limit :: pos_integer(),
          value_length_limit :: pos_integer() | :infinity
        ) :: {%{String.t() => primitive_any()}, non_neg_integer()}
  defp apply_attribute_limits(attributes, count_limit, value_length_limit) do
    limited =
      attributes
      |> Enum.take(count_limit)
      |> Enum.map(fn {key, value} ->
        {key, truncate_value(value, value_length_limit)}
      end)
      |> Map.new()

    {limited, max(map_size(attributes) - count_limit, 0)}
  end

  # Spec common/README.md L260-L274 truncation rules. Recurses
  # through nested maps and AnyValue arrays per L270-L273. The
  # case shape mirrors `Otel.SDK.Logs.LogRecordLimits.do_truncate/2`.
  @spec truncate_value(value :: primitive_any(), limit :: pos_integer() | :infinity) ::
          primitive_any()
  defp truncate_value(value, :infinity), do: value

  defp truncate_value({:bytes, bin}, limit) when is_binary(bin) and byte_size(bin) > limit do
    {:bytes, binary_part(bin, 0, limit)}
  end

  defp truncate_value(value, limit) when is_binary(value) do
    if String.length(value) > limit, do: String.slice(value, 0, limit), else: value
  end

  defp truncate_value(value, limit) when is_list(value) do
    Enum.map(value, &truncate_value(&1, limit))
  end

  defp truncate_value(value, limit) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, truncate_value(v, limit)} end)
  end

  defp truncate_value(value, _limit), do: value

  @spec exception_type(exception :: Exception.t()) :: String.t()
  defp exception_type(exception) do
    exception.__struct__ |> Atom.to_string() |> String.trim_leading("Elixir.")
  end
end
