defmodule Otel.API.Trace.Span do
  @moduledoc """
  Span operations facade (OTel `trace/api.md` §Span operations
  L449-L705; Status: **Stable**).

  All operations dispatch to the SDK-registered span module via
  `get_module/0` and no-op when no SDK is installed (spec
  L860-L874 *"Behavior of the API in the absence of an installed
  SDK"*). Once the span has ended, subsequent mutations SHOULD
  be silently ignored (spec L652-L653 *"the Span becomes
  non-recording by being ended"*).

  ## BEAM representation

  On BEAM there is no separate mutable `Span` object — the API
  takes a `SpanContext` as the handle and the SDK resolves it
  to the actual span record stored in ETS. `get_context/1` is
  therefore identity; spec L461 *"returned value MUST be the
  same for the entire Span lifetime"* is satisfied
  automatically by the value-semantic `SpanContext`.

  All functions are safe for concurrent use.

  ## Public API

  | Function | Role |
  |---|---|
  | `get_context/1` | **OTel API MUST** (GetContext, L458-L461) |
  | `recording?/1` | **OTel API MUST** (IsRecording, L463-L493) |
  | `set_attribute/3` | **OTel API MUST** (SetAttribute, L495-L520) |
  | `set_attributes/2` | **OTel API MAY** (L506-L508) |
  | `add_event/2` | **OTel API MUST** (AddEvent, L525-L557) |
  | `add_link/2` | **OTel API MUST** (AddLink, L562-L564) |
  | `set_status/2` | **OTel API MUST** (SetStatus, L565-L624) |
  | `update_name/2` | **OTel API MUST** (UpdateName, L628-L645) |
  | `end_span/2` | **OTel API MUST** (End, L647-L682) |
  | `record_exception/4` | **OTel API SHOULD** (Record Exception, L684-L704 + `exceptions.md` L44-L55) |
  | `set_module/1`, `get_module/0` | **Local helper** — SDK dispatch registration |

  ## References

  - OTel Trace API §Span operations: `opentelemetry-specification/specification/trace/api.md` L449-L705
  - OTel Trace API §Behavior in absence of SDK: `opentelemetry-specification/specification/trace/api.md` L860-L874
  - OTel Trace Exceptions §Attributes: `opentelemetry-specification/specification/trace/exceptions.md` L44-L55
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_span.erl`
  """

  use Otel.API.Common.Types

  @typedoc """
  Options accepted by `Otel.API.Trace.Tracer` callback
  `start_span/4` and by facade `Otel.API.Trace.start_span/3,4`.

  Keys mirror the parameters required by spec L386-L414
  (§Span Creation): `kind`, `attributes`, `links`, `start_time`,
  and a language-local `is_root` flag used by the SDK to skip
  parent resolution.
  """
  @type start_opts :: [
          kind: Otel.API.Trace.SpanKind.t(),
          attributes: %{String.t() => primitive() | [primitive()]},
          links: [Otel.API.Trace.Link.t()],
          start_time: timestamp(),
          is_root: boolean()
        ]

  @module_key {__MODULE__, :module}

  @doc """
  **OTel API MUST** — "Get Context" (`trace/api.md` L458-L461).

  Returns the `SpanContext` associated with this span. On BEAM
  the SpanContext is itself the handle, so this is identity;
  per spec L461 the returned value MUST be the same for the
  entire Span lifetime — satisfied automatically by value
  semantics.
  """
  @spec get_context(span_ctx :: Otel.API.Trace.SpanContext.t()) :: Otel.API.Trace.SpanContext.t()
  def get_context(%Otel.API.Trace.SpanContext{} = span_ctx), do: span_ctx

  @doc """
  **OTel API MUST** — "IsRecording" (`trace/api.md` L463-L493).

  Returns whether the span is currently recording data. Per
  spec L472-L476 IsRecording is independent of the sampled
  flag in `TraceFlags` — a span may be recording locally while
  the trace is not sampled for export. Per spec L478-L481 an
  ended span SHOULD become non-recording.

  Without an SDK installed always returns `false`.
  """
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.API.Trace.SpanContext{} = span_ctx) do
    case get_module() do
      nil -> false
      module -> module.recording?(span_ctx)
    end
  end

  @doc """
  **OTel API MUST** — "SetAttribute" (`trace/api.md`
  L495-L520).

  Sets a single attribute on the span. Per spec L513-L514
  setting an attribute with the same key as an existing
  attribute SHOULD overwrite the previous value.

  Silently ignored if the span is non-recording (L468-L469) or
  already ended (L652-L653).
  """
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t(),
          value :: primitive() | [primitive()]
        ) :: :ok
  def set_attribute(%Otel.API.Trace.SpanContext{} = span_ctx, key, value) do
    case get_module() do
      nil -> :ok
      module -> module.set_attribute(span_ctx, key, value)
    end
  end

  @doc """
  **OTel API MAY** — "SetAttributes" convenience
  (`trace/api.md` L506-L508).

  Sets multiple attributes in a single call. Per spec this is
  a MAY convenience over repeated `set_attribute/3`; same
  overwrite and recording-state rules apply.
  """
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) ::
          :ok
  def set_attributes(%Otel.API.Trace.SpanContext{} = span_ctx, attributes) do
    case get_module() do
      nil -> :ok
      module -> module.set_attributes(span_ctx, attributes)
    end
  end

  @doc """
  **OTel API MUST** — "AddEvent" (`trace/api.md` L525-L557).

  Records an event on the span. The caller constructs the
  `Event` via `Otel.API.Trace.Event.new/3` — per spec L543-L544
  if no timestamp is supplied the implementation sets it to
  the time at which the API is called.

  Per spec L547 events SHOULD preserve the order in which they
  are recorded.
  """
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          event :: Otel.API.Trace.Event.t()
        ) :: :ok
  def add_event(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Event{} = event) do
    case get_module() do
      nil -> :ok
      module -> module.add_event(span_ctx, event)
    end
  end

  @doc """
  **OTel API MUST** — "Add Link" (`trace/api.md` L562-L564).

  Adds a link to another span after creation. Per spec L563
  adding links at span creation (via `Tracer.start_span/4`
  opts) is preferred — samplers may not consider links added
  later.
  """
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          link :: Otel.API.Trace.Link.t()
        ) :: :ok
  def add_link(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Link{} = link) do
    case get_module() do
      nil -> :ok
      module -> module.add_link(span_ctx, link)
    end
  end

  @doc """
  **OTel API MUST** — "SetStatus" (`trace/api.md` L565-L624).

  Sets the status of the span. Status priority per spec L590
  *"These values form a total order: Ok > Error > Unset"*:

  - L599 `Description` MUST be IGNORED for `:ok` and `:unset`
    (also enforced by `Otel.API.Trace.Status.new/2`)
  - L604 an attempt to set `:unset` SHOULD be ignored
  - L619-L620 once set to `:ok`, the status SHOULD be
    considered final and further attempts SHOULD be ignored
  """
  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          status :: Otel.API.Trace.Status.t()
        ) :: :ok
  def set_status(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Status{} = status) do
    case get_module() do
      nil -> :ok
      module -> module.set_status(span_ctx, status)
    end
  end

  @doc """
  **OTel API MUST** — "UpdateName" (`trace/api.md` L628-L645).

  Updates the span name. Per spec L632-L634 any sampling
  behaviour based on span name is implementation-dependent —
  samplers can only consider information already present
  during span creation.
  """
  @spec update_name(span_ctx :: Otel.API.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(%Otel.API.Trace.SpanContext{} = span_ctx, name) do
    case get_module() do
      nil -> :ok
      module -> module.update_name(span_ctx, name)
    end
  end

  @doc """
  **OTel API MUST** — "End" (`trace/api.md` L647-L682).

  Signals that the operation described by the span has ended.

  - L672-L673 if `timestamp` is omitted, the current time
    is used (*"MUST be treated equivalent to passing the
    current time"*) — the default arg evaluates
    `System.system_time(:nanosecond)` at call time
  - L652-L653 implementations SHOULD ignore subsequent calls
    to `end_span` and any other Span methods — the span
    becomes non-recording by being ended
  - L677 this operation MUST NOT perform blocking I/O on the
    calling thread
  - L665-L668 ending the span MUST NOT inactivate it in any
    Context it is active in — ended spans remain usable as
    parents

  L429-L430: *"Any span that is created MUST also be ended.
  This is the responsibility of the user."*

  Values are `t:timestamp/0` — Unix epoch nanoseconds (uint64),
  matching OTLP `time_unix_nano`.
  """
  @spec end_span(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          timestamp :: timestamp()
        ) :: :ok
  def end_span(
        %Otel.API.Trace.SpanContext{} = span_ctx,
        timestamp \\ System.system_time(:nanosecond)
      ) do
    case get_module() do
      nil -> :ok
      module -> module.end_span(span_ctx, timestamp)
    end
  end

  @doc """
  **OTel API SHOULD** — "Record Exception" (`trace/api.md`
  L684-L704, specialized `AddEvent` variant).

  Records an exception as an event on the span. Per spec L688
  this is a specialized variant of `AddEvent`; per L697-L699
  the method MUST accept an optional parameter for additional
  event attributes, which take precedence over attributes
  generated from the exception object.

  The event follows `trace/exceptions.md` §Attributes L44-L55:

  - event name: `"exception"` (MUST)
  - `exception.message` (SHOULD)
  - `exception.stacktrace` (SHOULD)
  - `exception.type` (SHOULD)
  """
  @spec record_exception(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def record_exception(
        %Otel.API.Trace.SpanContext{} = span_ctx,
        exception,
        stacktrace \\ [],
        attributes \\ %{}
      ) do
    case get_module() do
      nil -> :ok
      module -> module.record_exception(span_ctx, exception, stacktrace, attributes)
    end
  end

  @doc """
  **Local helper** — SDK dispatch registration hook.

  Called by `Otel.SDK.Application.start/2` to register the
  SDK's Span operations module. Operations in this API
  dispatch to the registered module via `get_module/0`.
  """
  @spec set_module(module :: module()) :: :ok
  def set_module(module) when is_atom(module) do
    :persistent_term.put(@module_key, module)
    :ok
  end

  @doc """
  **Local helper** — introspection of the registered SDK Span
  operations module.

  Returns `nil` when no SDK is installed; in that case all
  operations in this API no-op.
  """
  @spec get_module() :: module() | nil
  def get_module do
    :persistent_term.get(@module_key, nil)
  end
end
