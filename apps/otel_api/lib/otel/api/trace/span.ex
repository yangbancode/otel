defmodule Otel.API.Trace.Span do
  @moduledoc """
  Span operations facade (OTel `trace/api.md` §Span operations
  L449-L705; Status: **Stable**).

  All operations dispatch to the SDK-registered span module and
  no-op when no SDK is installed (spec
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

  This same identity satisfies spec §"Wrapping a SpanContext in
  a Span" (`trace/api.md` L720-L739) without a dedicated
  constructor: a `SpanContext` received from any source
  (propagator extraction, custom protocol bridge, manual
  reconstruction) is already a usable Span handle. Hand it to
  `Otel.API.Trace.set_current_span/1,2`, `make_current/1`, or
  any function on this module — the registered SDK module
  handles unknown spans as no-ops, satisfying the spec's
  non-recording requirement (L731-L734).

  ## Dispatch shape

  Unlike `Tracer` / `Meter` / `Logger` — which receive a
  `{module, config}` tuple as their handle and pattern-match on
  it — `Span`'s handle is a `SpanContext`, a pure W3C-defined
  data value that does not carry the SDK dispatcher. Instead,
  the SDK registers its Span operations module via
  `set_module/1` and each facade function looks it up through
  a private `get_module/0` which reads from
  `:persistent_term`.

  `get_module/0` defaults to `Otel.API.Trace.Span.Noop` when no
  SDK has registered, so every dispatch returns a valid
  module pointer and each facade function is a direct call.
  This mirrors how `TracerProvider.get_tracer/1` returns
  `{Tracer.Noop, []}` when no SDK is installed — a Noop
  dispatcher is always available, the absence-of-SDK branch is
  absorbed into the Noop module's own no-op implementations.

  All functions are safe for concurrent use.

  ## Public API

  | Function | Role |
  |---|---|
  | `get_context/1` | **Application** (OTel API MUST) — GetContext (L458-L461) |
  | `recording?/1` | **Application** (OTel API MUST) — IsRecording (L463-L493) |
  | `set_attribute/3` | **Application** (OTel API MUST) — SetAttribute (L495-L520) |
  | `set_attributes/2` | **Application** (OTel API MAY) — SetAttributes (L506-L508) |
  | `add_event/2` | **Application** (OTel API MUST) — AddEvent (L525-L557) |
  | `add_link/2` | **Application** (OTel API MUST) — AddLink (L562-L564) |
  | `set_status/2` | **Application** (OTel API MUST) — SetStatus (L565-L624) |
  | `update_name/2` | **Application** (OTel API MUST) — UpdateName (L628-L645) |
  | `end_span/2` | **Application** (OTel API MUST) — End (L647-L682) |
  | `record_exception/4` | **Application** (OTel API SHOULD) — Record Exception (L684-L704 + `exceptions.md` L44-L55) |
  | `@callback` for each of the above mutations | **SDK** (OTel API MUST/SHOULD) — SDK dispatch contract |
  | `set_module/1` | **SDK** (installation hook) — register SDK Span module |

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
          attributes: %{String.t() => primitive_any()},
          links: [Otel.API.Trace.Link.t()],
          start_time: non_neg_integer(),
          is_root: boolean()
        ]

  @module_key {__MODULE__, :module}

  # --- Application dispatch ---

  @doc """
  **Application** (OTel API MUST) — "Get Context" (`trace/api.md`
  L458-L461).

  Returns the `SpanContext` associated with this span. On BEAM
  the SpanContext is itself the handle, so this is identity;
  per spec L461 the returned value MUST be the same for the
  entire Span lifetime — satisfied automatically by value
  semantics.
  """
  @spec get_context(span_ctx :: Otel.API.Trace.SpanContext.t()) :: Otel.API.Trace.SpanContext.t()
  def get_context(%Otel.API.Trace.SpanContext{} = span_ctx), do: span_ctx

  @doc """
  **Application** (OTel API MUST) — "IsRecording" (`trace/api.md`
  L463-L493).

  Returns whether the span is currently recording data. Per
  spec L472-L476 IsRecording is independent of the sampled
  flag in `TraceFlags` — a span may be recording locally while
  the trace is not sampled for export. Per spec L478-L481 an
  ended span SHOULD become non-recording.

  Without an SDK installed always returns `false` via
  `Otel.API.Trace.Span.Noop`.
  """
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.API.Trace.SpanContext{} = span_ctx) do
    get_module().recording?(span_ctx)
  end

  @doc """
  **Application** (OTel API MUST) — "SetAttribute"
  (`trace/api.md` L495-L520).

  Sets a single attribute on the span. Per spec L513-L514
  setting an attribute with the same key as an existing
  attribute SHOULD overwrite the previous value.

  Silently ignored if the span is non-recording (L468-L469) or
  already ended (L652-L653).
  """
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t(),
          value :: primitive_any()
        ) :: :ok
  def set_attribute(%Otel.API.Trace.SpanContext{} = span_ctx, key, value) do
    get_module().set_attribute(span_ctx, key, value)
  end

  @doc """
  **Application** (OTel API MAY) — "SetAttributes" convenience
  (`trace/api.md` L506-L508).

  Sets multiple attributes in a single call. Per spec this is
  a MAY convenience over repeated `set_attribute/3`; same
  overwrite and recording-state rules apply.
  """
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: %{String.t() => primitive_any()}
        ) ::
          :ok
  def set_attributes(%Otel.API.Trace.SpanContext{} = span_ctx, attributes) do
    get_module().set_attributes(span_ctx, attributes)
  end

  @doc """
  **Application** (OTel API MUST) — "AddEvent" (`trace/api.md`
  L525-L557).

  Records an event on the span. The caller constructs the
  `Event` via `Otel.API.Trace.Event.new/3` — per spec L543-L544
  if no timestamp is supplied the implementation sets it to
  the time at which the API is called.

  Per spec L547 events SHOULD preserve the order in which
  they are recorded. This facade dispatches to the
  SDK-registered module, so ordering is the SDK
  implementation's responsibility; API users relying on order
  should confirm their SDK honours it.
  """
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          event :: Otel.API.Trace.Event.t()
        ) :: :ok
  def add_event(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Event{} = event) do
    get_module().add_event(span_ctx, event)
  end

  @doc """
  **Application** (OTel API MUST) — "Add Link" (`trace/api.md`
  L562-L564).

  Adds a link to another span after creation. Per spec L563
  adding links at span creation (via `Tracer.start_span/4`
  opts) is preferred — samplers may not consider links added
  later.

  Per spec L820-L823 SHOULD — *"Implementations SHOULD record
  links containing `SpanContext` with empty `TraceId` or
  `SpanId` (all zeros) as long as either the attribute set or
  `TraceState` is non-empty."* SDKs implementing the
  `add_link/2` callback are responsible for honouring this
  recording rule (the API facade is a pure dispatcher).
  """
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          link :: Otel.API.Trace.Link.t()
        ) :: :ok
  def add_link(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Link{} = link) do
    get_module().add_link(span_ctx, link)
  end

  @doc """
  **Application** (OTel API MUST) — "SetStatus" (`trace/api.md`
  L565-L624).

  Sets the status of the span. Per spec L590 status values form
  the total order `Ok > Error > Unset`. The MUST/SHOULD rules
  (L599 description IGNORE on `:ok`/`:unset`, L604 ignore
  `:unset` writes, L619-L620 `:ok` is final) are *recording-time*
  invariants and belong to the SDK implementation — see the
  `@callback set_status/2` contract below.

  This facade is a pure dispatcher; it forwards the
  caller-supplied `Status` verbatim. Callers building a
  `Status` via `Otel.API.Trace.Status.new/2` are protected from
  the L599 trap at construction time.
  """
  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          status :: Otel.API.Trace.Status.t()
        ) :: :ok
  def set_status(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Status{} = status) do
    get_module().set_status(span_ctx, status)
  end

  @doc """
  **Application** (OTel API MUST) — "UpdateName" (`trace/api.md`
  L628-L645).

  Updates the span name. Per spec L632-L634 any sampling
  behaviour based on span name is implementation-dependent —
  samplers can only consider information already present
  during span creation.
  """
  @spec update_name(span_ctx :: Otel.API.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(%Otel.API.Trace.SpanContext{} = span_ctx, name) do
    get_module().update_name(span_ctx, name)
  end

  @doc """
  **Application** (OTel API MUST) — "End" (`trace/api.md`
  L647-L682).

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

  Values are Unix epoch **nanoseconds** (OTLP
  `time_unix_nano`, a `fixed64` unsigned proto3 field).
  The typespec is `non_neg_integer()` enforcing the
  unsigned invariant at the API boundary.
  """
  @spec end_span(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          timestamp :: non_neg_integer()
        ) :: :ok
  def end_span(
        %Otel.API.Trace.SpanContext{} = span_ctx,
        timestamp \\ System.system_time(:nanosecond)
      ) do
    get_module().end_span(span_ctx, timestamp)
  end

  @doc """
  **Application** (OTel API SHOULD) — "Record Exception"
  (`trace/api.md` L684-L704, specialized `AddEvent` variant).

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
          attributes :: %{String.t() => primitive_any()}
        ) :: :ok
  def record_exception(
        %Otel.API.Trace.SpanContext{} = span_ctx,
        exception,
        stacktrace \\ [],
        attributes \\ %{}
      ) do
    get_module().record_exception(span_ctx, exception, stacktrace, attributes)
  end

  # --- SDK callbacks ---

  @doc """
  **SDK** (OTel API MUST) — "IsRecording" (`trace/api.md`
  L463-L493).

  Returns whether the span is currently recording. Per spec
  L472-L476 IsRecording is independent of the sampled flag in
  `TraceFlags`; per L478-L481 an ended span SHOULD become
  non-recording.
  """
  @callback recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()

  @doc """
  **SDK** (OTel API MUST) — "SetAttribute" (`trace/api.md`
  L495-L520).

  Per spec L513-L514 setting an attribute with the same key as
  an existing attribute SHOULD overwrite the previous value.
  Silently ignored if the span is non-recording (L468-L469) or
  already ended (L652-L653).
  """
  @callback set_attribute(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              key :: String.t(),
              value :: primitive_any()
            ) :: :ok

  @doc """
  **SDK** (OTel API MAY) — "SetAttributes" convenience
  (`trace/api.md` L506-L508).

  Sets multiple attributes in a single call. Same overwrite
  and recording-state rules as `set_attribute/3`.
  """
  @callback set_attributes(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              attributes :: %{String.t() => primitive_any()}
            ) :: :ok

  @doc """
  **SDK** (OTel API MUST) — "AddEvent" (`trace/api.md`
  L525-L557).

  Per spec L547 events SHOULD preserve the order in which
  they are recorded.
  """
  @callback add_event(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              event :: Otel.API.Trace.Event.t()
            ) :: :ok

  @doc """
  **SDK** (OTel API MUST) — "Add Link" (`trace/api.md`
  L562-L564).

  Per spec L563 adding links at span creation (via
  `Tracer.start_span/4` opts) is preferred — samplers may not
  consider links added later.

  Per spec L820-L823 SHOULD the SDK implementation **SHOULD
  record links containing a `SpanContext` with empty `TraceId`
  or `SpanId`** when either the attribute set or the
  `TraceState` is non-empty. Implementations should not
  silently drop such links.
  """
  @callback add_link(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              link :: Otel.API.Trace.Link.t()
            ) :: :ok

  @doc """
  **SDK** (OTel API MUST) — "SetStatus" (`trace/api.md`
  L565-L624).

  Status priority per L590: `Ok > Error > Unset`. The SDK
  implementation MUST honour:

  - **L599** `Description` MUST be IGNORED for `:ok` / `:unset`.
    A caller that constructed `%Status{}` directly may still
    pass a stale description on `:ok` / `:unset`; the SDK MUST
    drop it before recording.
  - **L604** SHOULD — an attempt to set `:unset` SHOULD be
    ignored (do not overwrite an existing `:ok` or `:error`).
  - **L619-L620** SHOULD — once the status is `:ok`, further
    `set_status` attempts SHOULD be ignored. `:ok` is final.
  """
  @callback set_status(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              status :: Otel.API.Trace.Status.t()
            ) :: :ok

  @doc """
  **SDK** (OTel API MUST) — "UpdateName" (`trace/api.md`
  L628-L645).
  """
  @callback update_name(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              name :: String.t()
            ) :: :ok

  @doc """
  **SDK** (OTel API MUST) — "End" (`trace/api.md` L647-L682).

  - L672-L673 if timestamp is omitted upstream, the facade
    substitutes `System.system_time(:nanosecond)`; this
    callback always receives an explicit integer
  - L652-L653 implementations SHOULD ignore subsequent calls
    to `end_span` and any other Span methods
  - L677 MUST NOT perform blocking I/O on the calling thread
  - L665-L668 ending the span MUST NOT inactivate it in any
    Context it is active in
  """
  @callback end_span(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              timestamp :: non_neg_integer()
            ) :: :ok

  @doc """
  **SDK** (OTel API SHOULD) — "Record Exception" (`trace/api.md`
  L684-L704 + `exceptions.md` L44-L55).

  A specialized variant of `AddEvent` (L688). Per L697-L699
  `attributes` take precedence over attributes generated from
  the exception object. The emitted event follows
  `exceptions.md` §Attributes L44-L55.
  """
  @callback record_exception(
              span_ctx :: Otel.API.Trace.SpanContext.t(),
              exception :: Exception.t(),
              stacktrace :: list(),
              attributes :: %{String.t() => primitive_any()}
            ) :: :ok

  # --- SDK installation hooks ---

  @doc """
  **SDK** (installation hook) — register the SDK Span operations
  module.

  Called by `Otel.SDK.Application.start/2` to register the
  SDK's Span operations module. The Application-tier operations
  in this module dispatch to the registered module; when no SDK
  has been installed, `get_module/0` falls back to
  `Otel.API.Trace.Span.Noop`.

  `module` must implement the `Otel.API.Trace.Span` behaviour.
  """
  @spec set_module(module :: module()) :: :ok
  def set_module(module) when is_atom(module) do
    :persistent_term.put(@module_key, module)
    :ok
  end

  # --- Private ---

  # Internal: resolve the currently-registered SDK Span
  # operations module, defaulting to `Otel.API.Trace.Span.Noop`
  # when no SDK has registered via `set_module/1`. Every
  # Application-tier function dispatches through this; the
  # Noop default removes any "no SDK installed" branch from
  # the facade, mirroring the `{Tracer.Noop, []}` default that
  # `TracerProvider.get_tracer/1` returns.
  #
  # Expressed as an explicit `case` rather than passing
  # `Span.Noop` as the 2-arg default to
  # `:persistent_term.get/2` so both branches (registered
  # module / Noop fallback) are hit repeatedly by every
  # no-SDK and every dispatch-to-registered-module test.
  # `mix test --cover` / `:cover`'s per-line counters have a
  # known quirk where many similar-shape function heads in a
  # single module can drop a hit under certain test-ordering
  # seeds (e.g. 863017); concentrating the branching here
  # gives the counters enough traffic to stabilise.
  @spec get_module() :: module()
  defp get_module do
    case :persistent_term.get(@module_key, nil) do
      nil -> Otel.API.Trace.Span.Noop
      module -> module
    end
  end
end
