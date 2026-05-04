defmodule Otel.Trace.Span do
  @moduledoc """
  SDK implementation of the `Otel.Trace.Span` behaviour
  (`trace/sdk.md` §Span L692-L944) — data + lifecycle
  operations.

  Holds all span data during its lifecycle. Creation is a pure
  operation; all mutating operations read/write the span in ETS via
  `SpanStorage` and are no-ops when the span is not in ETS (already
  ended or dropped), satisfying spec `trace/api.md` L478-L481
  (an ended span SHOULD become non-recording).

  Registered as the global span module on SDK application start;
  the API layer's `Otel.Trace.Span` dispatches to the functions
  defined here via the `Otel.Trace.Span` behaviour.

  All functions are safe for concurrent use — every mutation
  goes through `:ets.update_element` / `:ets.insert` against
  the public `SpanStorage` table, satisfying spec L883
  (*"Span — all methods MUST be documented that
  implementations need to be safe for concurrent use by
  default."*).

  ## Public API

  | Callback | Role |
  |---|---|
  | `start_span/4` | **SDK** (lifecycle) — sampler + id-generator + storage insert |
  | `recording?/1`, `set_attribute/3`, `set_attributes/2`, `add_event/2`, `add_link/2`, `set_status/2`, `update_name/2`, `record_exception/4`, `end_span/2` | **SDK** (OTel API MUST/SHOULD) — `trace/api.md` §Span operations L449-L705 |

  ## Design notes

  ### Span-resident SpanLimits

  `span_limits` is stored as a field on each span rather than
  threaded through call arguments or fetched from a global
  registry, so `set_attribute/3`, `add_event/2`, etc. operate
  on the span fetched from `SpanStorage` without a second
  lookup. The value comes from `Otel.Trace.Tracer`'s compile-time
  `@span_limits` literal — minikube hardcodes the spec defaults
  and exposes no override.

  This diverges from `opentelemetry-erlang`, which threads
  limits through `otel_span_utils` per call
  (`opentelemetry/src/otel_span_utils.erl`).

  ### Dropped-count tracking on SDK types

  Spec `common/mapping-to-non-otlp.md` L75-L77 (linked from
  `trace/sdk.md` L260-L262) MUST: *"OpenTelemetry dropped
  attributes count MUST be reported as a key-value pair
  associated with the corresponding data entity (e.g. Span,
  Span Link, Span Event, Metric data point, LogRecord)."*

  Five counters are tracked, all on SDK-layer types:

  - `Otel.Trace.Span.dropped_attributes_count` (proto
    `Span` field 10)
  - `Otel.Trace.Span.dropped_events_count` (proto `Span`
    field 12)
  - `Otel.Trace.Span.dropped_links_count` (proto `Span`
    field 14)
  - `Otel.Trace.Event.dropped_attributes_count` (proto
    `Span.Event` field 4)
  - `Otel.Trace.Link.dropped_attributes_count` (proto
    `Span.Link` field 5)

  `Otel.Trace.Event` and `Otel.Trace.Link` are SDK
  wrapper structs constructed from the API-layer
  `Otel.Trace.Event` / `Otel.Trace.Link` at the
  moment limits are applied. Keeping the count off the API
  types preserves API↛SDK layer independence
  (`.claude/rules/code-conventions.md`); the API spec
  (`trace/api.md` §Add Events L520-L558, §Link L803-L834)
  does not define `dropped_attributes_count` on Event/Link.

  Counters are incremented at every callsite where
  `SpanLimits` causes a discard: `start_span/4` (initial
  attributes/events/links), `set_attribute/3`,
  `set_attributes/2`, `add_event/2`, and `add_link/2`. Per
  spec `common/README.md` L262-L274, value-length truncation
  is **not** a drop — only count-limit overflow is.

  ### `instrumentation_scope` on the span

  This field exists on the span but does not appear in the
  proto `Span` message — it is held on the span for grouping
  into `ScopeSpans` at export time.

  Recording status is **not** a struct field. spec
  `trace/api.md` §IsRecording L463-L495 requires only a
  *function returning bool* (no struct shape mandated);
  `Otel.Trace.Span.recording?/1` derives it from
  `Otel.Trace.SpanStorage.get_active/1` (presence of an
  `:active` row). Storage status is the single source of
  truth, avoiding stale-replica risk between the struct field
  and storage.

  ## References

  - OTel Trace SDK §Span: `opentelemetry-specification/specification/trace/sdk.md` L692-L944
  - OTel Trace API §Span: `opentelemetry-specification/specification/trace/api.md` L449-L705
  - OTLP proto Span: `opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto`
  """

  use Otel.Common.Types

  @typedoc """
  Options accepted by `Otel.Trace.Tracer.start_span/3`.

  - `:kind` — `t:Otel.Trace.SpanKind.t/0`. Spec L405-L406.
  - `:attributes` — initial attributes. Spec L407-L409.
  - `:links` — initial Links. Spec L410-L412.
  - `:start_time` — explicit start timestamp (nanoseconds since
    the Unix epoch). Spec L413-L414.
  - `:is_root` — boolean indicator that this Span should be a
    root Span, ignoring whatever current span the resolved
    Context carries. Spec L390-L391.
  """
  @type start_opts :: [
          kind: Otel.Trace.SpanKind.t(),
          attributes: %{String.t() => primitive_any()},
          links: [Otel.Trace.Link.t()],
          start_time: non_neg_integer(),
          is_root: boolean()
        ]

  require Logger

  @type t :: %__MODULE__{
          trace_id: Otel.Trace.TraceId.t(),
          span_id: Otel.Trace.SpanId.t(),
          tracestate: Otel.Trace.TraceState.t(),
          parent_span_id: Otel.Trace.SpanId.t() | nil,
          parent_span_is_remote: boolean() | nil,
          name: String.t(),
          kind: Otel.Trace.SpanKind.t(),
          start_time: non_neg_integer(),
          end_time: non_neg_integer() | nil,
          attributes: %{String.t() => primitive_any()},
          dropped_attributes_count: non_neg_integer(),
          events: [Otel.Trace.Event.t()],
          dropped_events_count: non_neg_integer(),
          links: [Otel.Trace.Link.t()],
          dropped_links_count: non_neg_integer(),
          status: Otel.Trace.Status.t(),
          trace_flags: Otel.Trace.SpanContext.trace_flags(),
          instrumentation_scope: Otel.InstrumentationScope.t() | nil,
          span_limits: Otel.Trace.SpanLimits.t()
        }

  defstruct [
    :trace_id,
    :span_id,
    :parent_span_id,
    :parent_span_is_remote,
    :name,
    :end_time,
    :instrumentation_scope,
    tracestate: Otel.Trace.TraceState.new(),
    kind: :internal,
    start_time: 0,
    attributes: %{},
    dropped_attributes_count: 0,
    events: [],
    dropped_events_count: 0,
    links: [],
    dropped_links_count: 0,
    status: %Otel.Trace.Status{},
    trace_flags: 0,
    span_limits: %Otel.Trace.SpanLimits{}
  ]

  # --- Creation ---

  @doc """
  Creates a span following the SDK creation flow (spec L339).

  Returns `{span_ctx, span | nil}` where span is nil for dropped spans.
  """
  @spec start_span(
          ctx :: Otel.Ctx.t(),
          name :: String.t(),
          span_limits :: Otel.Trace.SpanLimits.t(),
          opts :: Otel.Trace.Span.start_opts()
        ) :: {Otel.Trace.SpanContext.t(), t() | nil}
  def start_span(ctx, name, span_limits, opts) do
    kind = Keyword.get(opts, :kind, :internal)
    attributes = Keyword.get(opts, :attributes, %{})
    links = Keyword.get(opts, :links, [])
    start_time = Keyword.get(opts, :start_time, System.system_time(:nanosecond))

    {span_ctx, parent_span_id, parent_is_remote} = new_span_ctx(ctx, opts)

    trace_id = span_ctx.trace_id
    span_id = span_ctx.span_id

    {trace_flags, is_recording, sampler_attributes, tracestate} =
      sample(ctx, trace_id, links, name, kind, attributes)

    span_ctx = %Otel.Trace.SpanContext{
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

      sdk_links =
        links
        |> Enum.take(span_limits.link_count_limit)
        |> Enum.map(&to_sdk_link(&1, span_limits))

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
        links: sdk_links,
        dropped_links_count: dropped_links_count,
        trace_flags: trace_flags
      }

      {span_ctx, span}
    else
      {span_ctx, nil}
    end
  end

  # --- Lifecycle operations (ETS-backed) ---

  @doc """
  Returns the SpanContext as-is. Identity function — on BEAM the
  SpanContext is itself the handle, satisfying spec `trace/api.md`
  L461 *"returned value MUST be the same for the entire Span
  lifetime"* automatically by value semantics.
  """
  @spec get_context(span_ctx :: Otel.Trace.SpanContext.t()) :: Otel.Trace.SpanContext.t()
  def get_context(%Otel.Trace.SpanContext{} = span_ctx), do: span_ctx

  @doc """
  Returns whether the span is currently recording.
  """

  @spec recording?(span_ctx :: Otel.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.Trace.SpanContext{span_id: span_id}) do
    Otel.Trace.SpanStorage.get_active(span_id) != nil
  end

  @doc """
  Sets a single attribute on the span.
  """

  @spec set_attribute(
          span_ctx :: Otel.Trace.SpanContext.t(),
          key :: String.t(),
          value :: primitive_any()
        ) :: :ok
  def set_attribute(%Otel.Trace.SpanContext{span_id: span_id}, key, value) do
    Otel.Trace.SpanStorage.update_active(span_id, fn span ->
      limits = span.span_limits
      value = truncate_value(value, limits.attribute_value_length_limit)

      {attributes, drop_inc} =
        put_attribute(span.attributes, key, value, limits.attribute_count_limit)

      %{
        span
        | attributes: attributes,
          dropped_attributes_count: span.dropped_attributes_count + drop_inc
      }
    end)
  end

  @doc """
  Sets multiple attributes on the span.
  """

  @spec set_attributes(
          span_ctx :: Otel.Trace.SpanContext.t(),
          attributes ::
            %{String.t() => primitive_any()}
            | [{String.t(), primitive_any()}]
        ) :: :ok
  def set_attributes(%Otel.Trace.SpanContext{span_id: span_id}, new_attributes) do
    new_attributes =
      if is_list(new_attributes), do: Map.new(new_attributes), else: new_attributes

    Otel.Trace.SpanStorage.update_active(span_id, fn span ->
      {attributes, drop_inc} =
        merge_attributes(new_attributes, span.attributes, span.span_limits)

      %{
        span
        | attributes: attributes,
          dropped_attributes_count: span.dropped_attributes_count + drop_inc
      }
    end)
  end

  @doc """
  Adds an event to the span.
  """

  @spec add_event(
          span_ctx :: Otel.Trace.SpanContext.t(),
          event :: Otel.Trace.Event.t()
        ) :: :ok
  def add_event(
        %Otel.Trace.SpanContext{span_id: span_id},
        %Otel.Trace.Event{} = event
      ) do
    Otel.Trace.SpanStorage.update_active(span_id, fn span ->
      limits = span.span_limits

      if length(span.events) < limits.event_count_limit do
        sdk_event = to_sdk_event(event, limits)
        %{span | events: span.events ++ [sdk_event]}
      else
        %{span | dropped_events_count: span.dropped_events_count + 1}
      end
    end)
  end

  @doc """
  Adds a link to another span after creation.
  """

  @spec add_link(
          span_ctx :: Otel.Trace.SpanContext.t(),
          link :: Otel.Trace.Link.t()
        ) :: :ok
  def add_link(
        %Otel.Trace.SpanContext{span_id: span_id},
        %Otel.Trace.Link{} = link
      ) do
    Otel.Trace.SpanStorage.update_active(span_id, fn span ->
      limits = span.span_limits

      if length(span.links) < limits.link_count_limit do
        sdk_link = to_sdk_link(link, limits)
        %{span | links: span.links ++ [sdk_link]}
      else
        %{span | dropped_links_count: span.dropped_links_count + 1}
      end
    end)
  end

  @doc """
  Sets the status of the span.

  Status priority: Ok > Error > Unset. Once set to :ok, status is final.
  Setting :unset is always ignored.
  """

  @spec set_status(
          span_ctx :: Otel.Trace.SpanContext.t(),
          status :: Otel.Trace.Status.t()
        ) :: :ok
  def set_status(
        %Otel.Trace.SpanContext{span_id: span_id},
        %Otel.Trace.Status{} = status
      ) do
    Otel.Trace.SpanStorage.update_active(span_id, &apply_set_status(&1, status))
  end

  @doc """
  Updates the name of the span.
  """

  @spec update_name(span_ctx :: Otel.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(%Otel.Trace.SpanContext{span_id: span_id}, name) do
    Otel.Trace.SpanStorage.update_active(span_id, &%{&1 | name: name})
  end

  @doc """
  Ends the span.

  Marks the span as `:completed` in `SpanStorage` (status flip
  + `end_time` stamp). `SpanExporter` picks it up on the next
  timer tick.
  """

  @spec end_span(span_ctx :: Otel.Trace.SpanContext.t(), timestamp :: non_neg_integer()) ::
          :ok
  def end_span(span_ctx, timestamp \\ System.system_time(:nanosecond))

  def end_span(%Otel.Trace.SpanContext{span_id: span_id}, timestamp) do
    end_time = timestamp || System.system_time(:nanosecond)

    case Otel.Trace.SpanStorage.mark_completed(span_id, end_time) do
      nil -> :ok
      ended_span -> warn_span_limits_applied(ended_span)
    end

    :ok
  end

  @doc """
  Records an exception as an event on the span.
  """

  @spec record_exception(
          span_ctx :: Otel.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: %{String.t() => primitive_any()}
        ) :: :ok
  def record_exception(span_ctx, exception, stacktrace \\ [], attributes \\ %{})

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

    add_event(span_ctx, Otel.Trace.Event.new("exception", exception_attributes))
  end

  # --- Private helpers ---

  @spec new_span_ctx(
          ctx :: Otel.Ctx.t(),
          opts :: Otel.Trace.Span.start_opts()
        ) :: {Otel.Trace.SpanContext.t(), Otel.Trace.SpanId.t() | nil, boolean() | nil}
  defp new_span_ctx(ctx, opts) do
    parent = Otel.Trace.current_span(ctx)
    is_root = Keyword.get(opts, :is_root, false)

    if is_root or not Otel.Trace.SpanContext.valid?(parent) do
      root_span_ctx()
    else
      child_span_ctx(parent)
    end
  end

  @spec child_span_ctx(parent :: Otel.Trace.SpanContext.t()) ::
          {Otel.Trace.SpanContext.t(), Otel.Trace.SpanId.t(), boolean()}
  defp child_span_ctx(parent) do
    span_id = Otel.Trace.IdGenerator.generate_span_id()

    {
      %Otel.Trace.SpanContext{
        trace_id: parent.trace_id,
        span_id: span_id,
        tracestate: parent.tracestate,
        is_remote: false
      },
      parent.span_id,
      parent.is_remote
    }
  end

  @spec root_span_ctx() :: {Otel.Trace.SpanContext.t(), nil, nil}
  defp root_span_ctx do
    trace_id = Otel.Trace.IdGenerator.generate_trace_id()
    span_id = Otel.Trace.IdGenerator.generate_span_id()

    {
      %Otel.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        is_remote: false
      },
      nil,
      nil
    }
  end

  @spec sample(
          ctx :: Otel.Ctx.t(),
          trace_id :: Otel.Trace.TraceId.t(),
          links :: [Otel.Trace.Link.t()],
          name :: String.t(),
          kind :: Otel.Trace.SpanKind.t(),
          attributes :: %{String.t() => primitive_any()}
        ) ::
          {Otel.Trace.SpanContext.trace_flags(), boolean(), %{String.t() => primitive_any()},
           Otel.Trace.TraceState.t()}
  defp sample(ctx, trace_id, links, name, kind, attributes) do
    {decision, new_attributes, tracestate} =
      Otel.Trace.Sampler.should_sample(ctx, trace_id, links, name, kind, attributes)

    case decision do
      :drop -> {0, false, new_attributes, tracestate}
      :record_and_sample -> {1, true, new_attributes, tracestate}
    end
  end

  @spec merge_attributes(
          new_attributes :: %{String.t() => primitive_any()},
          existing :: %{String.t() => primitive_any()},
          limits :: Otel.Trace.SpanLimits.t()
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

  @spec to_sdk_event(
          event :: Otel.Trace.Event.t(),
          limits :: Otel.Trace.SpanLimits.t()
        ) :: Otel.Trace.Event.t()
  defp to_sdk_event(%Otel.Trace.Event{} = event, limits) do
    {limited_attributes, dropped} =
      apply_attribute_limits(
        event.attributes,
        limits.attribute_per_event_limit,
        limits.attribute_value_length_limit
      )

    %Otel.Trace.Event{
      name: event.name,
      timestamp: event.timestamp,
      attributes: limited_attributes,
      dropped_attributes_count: dropped
    }
  end

  @spec to_sdk_link(
          link :: Otel.Trace.Link.t(),
          limits :: Otel.Trace.SpanLimits.t()
        ) :: Otel.Trace.Link.t()
  defp to_sdk_link(%Otel.Trace.Link{} = link, limits) do
    {limited_attributes, dropped} =
      apply_attribute_limits(
        link.attributes,
        limits.attribute_per_link_limit,
        limits.attribute_value_length_limit
      )

    %Otel.Trace.Link{
      context: link.context,
      attributes: limited_attributes,
      dropped_attributes_count: dropped
    }
  end

  @spec apply_set_status(
          span :: t(),
          status :: Otel.Trace.Status.t()
        ) :: t()
  defp apply_set_status(span, %Otel.Trace.Status{code: :unset}), do: span

  defp apply_set_status(%{status: %Otel.Trace.Status{code: :ok}} = span, _status), do: span

  defp apply_set_status(span, %Otel.Trace.Status{code: :ok}) do
    %{span | status: %Otel.Trace.Status{code: :ok, description: ""}}
  end

  defp apply_set_status(span, %Otel.Trace.Status{code: :error, description: description}) do
    %{span | status: %Otel.Trace.Status{code: :error, description: description}}
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
  # case shape mirrors `Otel.Logs.LogRecordLimits.do_truncate/2`.
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

  # Spec `trace/sdk.md` L873-L876 SHOULD: *"There SHOULD be a
  # message printed in the SDK's log to indicate to the user
  # that an attribute, event, or link was discarded due to such
  # a limit. To prevent excessive logging, the message MUST be
  # printed at most once per span."*
  #
  # Called once from `end_span/2`, structurally satisfying the
  # MUST-once-per-span constraint without per-span state.
  @spec warn_span_limits_applied(span :: t()) :: :ok
  defp warn_span_limits_applied(span) do
    parts =
      [
        {span.dropped_attributes_count, "attribute"},
        {span.dropped_events_count, "event"},
        {span.dropped_links_count, "link"}
      ]
      |> Enum.filter(fn {n, _} -> n > 0 end)
      |> Enum.map(fn {n, label} -> "#{n} #{label}#{if n == 1, do: "", else: "s"}" end)

    if parts != [] do
      Logger.warning("Otel.Trace.Span: span limits applied — dropped #{Enum.join(parts, ", ")}")
    end

    :ok
  end
end
