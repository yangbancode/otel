defmodule Otel.API.Trace do
  @moduledoc """
  Trace API facade — TracerProvider, Context Interaction, and
  Span Creation entry points (OTel `trace/api.md`
  §TracerProvider L88-L157, §Context Interaction L159-L183,
  §Span Creation L378-L414).

  Thin dispatcher over `Otel.API.Trace.TracerProvider` and the
  registered Tracer implementation. Context Interaction
  functions read/write span-in-context using a module-private
  key so user code never needs to know the Context Key
  (spec L171-L173 *"API users SHOULD NOT have access to the
  Context Key"*).

  Span Creation dispatches through the Tracer's
  `start_span/4`; the new Span is **not** automatically set
  as the active span (spec L382). Use `with_span/4,5` for
  automatic context management including exception recording
  (spec L385 *"MAY be offered additionally as a separate
  operation"*).

  ## Public API

  | Function | Role |
  |---|---|
  | `get_tracer/1` | **Local helper** — facade over `TracerProvider` |
  | `current_span/1` | **OTel API MUST** — Extract Span from Context (L167) |
  | `set_current_span/2` | **OTel API MUST** — Combine Span with Context (L168) |
  | `current_span/0` | **OTel API SHOULD** — Get active span from implicit context (L177) |
  | `set_current_span/1` | **OTel API SHOULD** — Set active span into implicit context (L178) |
  | `start_span/3`, `start_span/4` | **OTel API MUST** — Span Creation (L378-L414) |
  | `with_span/4`, `with_span/5` | **OTel convenience** — MAY be offered as separate operation (L385) |

  ## References

  - OTel Trace API §TracerProvider: `opentelemetry-specification/specification/trace/api.md` L88-L157
  - OTel Trace API §Context Interaction: `opentelemetry-specification/specification/trace/api.md` L159-L183
  - OTel Trace API §Span Creation: `opentelemetry-specification/specification/trace/api.md` L378-L414
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_tracer.erl`
  """

  @typedoc "Options for span creation. See `Otel.API.Trace.Span.start_opts/0`."
  @type start_opts :: Otel.API.Trace.Span.start_opts()

  @span_key {__MODULE__, :span}

  @doc """
  **Local helper** — facade over `Otel.API.Trace.TracerProvider`.

  Returns a Tracer for the given instrumentation scope.
  Equivalent to calling `Otel.API.Trace.TracerProvider.get_tracer/1`
  directly but exposed on `Otel.API.Trace` as the user-facing
  entry point.
  """
  @spec get_tracer(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Trace.Tracer.t()
  def get_tracer(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    Otel.API.Trace.TracerProvider.get_tracer(instrumentation_scope)
  end

  @doc """
  **OTel API MUST** — "Extract the Span from a Context instance"
  (`trace/api.md` L167).

  Reads the SpanContext stored in `ctx`. When no span has been
  set, returns an empty `SpanContext` struct — the invalid
  sentinel (W3C §trace-id L103 + §parent-id L114).
  """
  @spec current_span(ctx :: Otel.API.Ctx.t()) :: Otel.API.Trace.SpanContext.t()
  def current_span(ctx) do
    Otel.API.Ctx.get_value(ctx, @span_key) || %Otel.API.Trace.SpanContext{}
  end

  @doc """
  **OTel API MUST** — "Combine the Span with a Context instance,
  creating a new Context instance" (`trace/api.md` L168).

  Returns a new context with `span_ctx` stored under the Tracing
  API's private key. `ctx` is not modified.
  """
  @spec set_current_span(ctx :: Otel.API.Ctx.t(), span_ctx :: Otel.API.Trace.SpanContext.t()) ::
          Otel.API.Ctx.t()
  def set_current_span(ctx, span_ctx) do
    Otel.API.Ctx.set_value(ctx, @span_key, span_ctx)
  end

  @doc """
  **OTel API SHOULD** — "Get the currently active span from the
  implicit context" (`trace/api.md` L177).

  Equivalent to `current_span(Otel.API.Ctx.current())` reading
  from the process-local ambient context.
  """
  @spec current_span() :: Otel.API.Trace.SpanContext.t()
  def current_span do
    Otel.API.Ctx.get_value(@span_key) || %Otel.API.Trace.SpanContext{}
  end

  @doc """
  **OTel API SHOULD** — "Set the currently active span into a
  new context, and make that the implicit context"
  (`trace/api.md` L178).

  Writes `span_ctx` under the Tracing API's private key in the
  process-local ambient context.
  """
  @spec set_current_span(span_ctx :: Otel.API.Trace.SpanContext.t()) :: :ok
  def set_current_span(span_ctx) do
    Otel.API.Ctx.set_value(@span_key, span_ctx)
  end

  # --- Span Creation ---

  @doc """
  **OTel API MUST** — Span Creation using the implicit
  (process-local) context as parent (`trace/api.md` L378-L414).

  Per spec L382, the newly created span is **not** automatically
  set as the current span. Use `with_span/4,5` for automatic
  context management.

  Per spec L403, adding attributes via `opts[:attributes]` at
  creation is preferred over `Span.set_attribute/3` later —
  samplers can only consider information already present during
  creation.
  """
  @spec start_span(tracer :: Otel.API.Trace.Tracer.t(), name :: String.t(), opts :: start_opts()) ::
          Otel.API.Trace.SpanContext.t()
  def start_span(tracer, name, opts \\ []) do
    start_span(Otel.API.Ctx.current(), tracer, name, opts)
  end

  @doc """
  **OTel API MUST** — Span Creation with an explicit parent
  context (`trace/api.md` L378-L414).

  Per spec L391-L392, only a full Context is accepted as the
  parent — not a raw Span or SpanContext. Per spec L382 the
  newly created span is not set as the current span.
  """
  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: start_opts()
        ) ::
          Otel.API.Trace.SpanContext.t()
  def start_span(ctx, {module, _config} = tracer, name, opts) do
    module.start_span(ctx, tracer, name, opts)
  end

  @doc """
  **OTel convenience** — dispatches to the Tracer's
  `with_span/5` callback using the implicit (process-local)
  context as parent (`trace/api.md` L385).

  Forwards to the registered Tracer implementation which owns
  the full span lifecycle (attach/fun/detach/end). See
  `Otel.API.Trace.Tracer.with_span/5` callback contract for
  lifecycle-ownership rationale.
  """
  @spec with_span(
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: start_opts(),
          fun :: (Otel.API.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  def with_span(tracer, name, opts \\ [], fun) do
    with_span(Otel.API.Ctx.current(), tracer, name, opts, fun)
  end

  @doc """
  **OTel convenience** — same as `with_span/4` but with an
  explicit parent context (`trace/api.md` L385).
  """
  @spec with_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: start_opts(),
          fun :: (Otel.API.Trace.SpanContext.t() -> result)
        ) ::
          result
        when result: term()
  def with_span(ctx, {module, _config} = tracer, name, opts, fun) do
    module.with_span(ctx, tracer, name, opts, fun)
  end
end
