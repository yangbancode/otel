defmodule Otel.Trace do
  @moduledoc """
  Trace API facade — Context Interaction and Span Creation
  entry points (OTel `trace/api.md` §Context Interaction
  L159-L183, §Span Creation L378-L414).

  Minikube has no plugin ecosystem, so the spec's TracerProvider
  + Tracer entities collapse to a single hardcoded identity. The
  facade exposes the closure-form `with_span/3,4` and explicit
  `start_span/2,3` directly — there's no Tracer handle to obtain
  via `get_tracer/0` first.

  Context Interaction functions read/write span-in-context using
  a module-private key so user code never needs to know the
  Context Key (spec L171-L173 *"API users SHOULD NOT have access
  to the Context Key"*).

  Span Creation does **not** automatically set the new span as
  the active span (spec L382). Use `with_span/3,4` for automatic
  context management including exception recording (spec L385
  *"MAY be offered additionally as a separate operation"*).

  All functions are safe for concurrent use (spec
  `trace/api.md` L843-L853 *"all methods MUST be documented
  that implementations need to be safe for concurrent use by
  default"*).

  ## Public API

  | Function | Role |
  |---|---|
  | `current_span/1` | **Application** (OTel API MUST) — Extract Span from Context (L167) |
  | `set_current_span/2` | **Application** (OTel API MUST) — Combine Span with Context (L168) |
  | `start_span/2`, `start_span/3` | **Application** (OTel API MUST) — Span Creation (L378-L414) |
  | `current_span/0` | **Application** (OTel API SHOULD) — Get active span from implicit context (L177) |
  | `set_current_span/1` | **Application** (OTel API SHOULD) — Set active span into implicit context (L178) |
  | `with_span/3`, `with_span/4` | **Application** (OTel API MAY) — closure-form separate operation (L385) |
  | `make_current/1` | **Application** (OTel API MAY) — manual "set active span" (L384-L386) |
  | `detach/1` | **Application** (OTel API MAY) — revert `make_current/1` (L384-L386) |

  ## References

  - OTel Trace API §Context Interaction: `opentelemetry-specification/specification/trace/api.md` L159-L183
  - OTel Trace API §Span Creation: `opentelemetry-specification/specification/trace/api.md` L378-L414
  """

  @typedoc "Options for span creation. See `Otel.Trace.Span.start_opts/0`."
  @type start_opts :: Otel.Trace.Span.start_opts()

  @span_key {__MODULE__, :span}

  @doc """
  **Application** (OTel API MUST) — "Extract the Span from a
  Context instance" (`trace/api.md` L167).

  Reads the SpanContext stored in `ctx`. When no span has been
  set, returns an empty `SpanContext` struct — the invalid
  sentinel (W3C §trace-id L103 + §parent-id L114).
  """
  @spec current_span(ctx :: Otel.Ctx.t()) :: Otel.Trace.SpanContext.t()
  def current_span(ctx) do
    Otel.Ctx.get_value(ctx, @span_key) || %Otel.Trace.SpanContext{}
  end

  @doc """
  **Application** (OTel API MUST) — "Combine the Span with a
  Context instance, creating a new Context instance"
  (`trace/api.md` L168).

  Returns a new context with `span_ctx` stored under the Tracing
  API's private key. `ctx` is not modified.
  """
  @spec set_current_span(ctx :: Otel.Ctx.t(), span_ctx :: Otel.Trace.SpanContext.t()) ::
          Otel.Ctx.t()
  def set_current_span(ctx, span_ctx) do
    Otel.Ctx.set_value(ctx, @span_key, span_ctx)
  end

  @doc """
  **Application** (OTel API SHOULD) — "Get the currently active
  span from the implicit context" (`trace/api.md` L177).

  Equivalent to `current_span(Otel.Ctx.current())` reading
  from the process-local ambient context.
  """
  @spec current_span() :: Otel.Trace.SpanContext.t()
  def current_span do
    Otel.Ctx.get_value(@span_key) || %Otel.Trace.SpanContext{}
  end

  @doc """
  **Application** (OTel API SHOULD) — "Set the currently active
  span into a new context, and make that the implicit context"
  (`trace/api.md` L178).

  Writes `span_ctx` under the Tracing API's private key in the
  process-local ambient context.
  """
  @spec set_current_span(span_ctx :: Otel.Trace.SpanContext.t()) :: :ok
  def set_current_span(span_ctx) do
    Otel.Ctx.set_value(@span_key, span_ctx)
  end

  # --- Span Creation ---

  @doc """
  **Application** (OTel API MUST) — Span Creation using the
  implicit (process-local) context as parent (`trace/api.md`
  L378-L414).

  Per spec L382, the newly created span is **not** automatically
  set as the current span. Use `with_span/3,4` for automatic
  context management.

  Per spec L403, adding attributes via `opts[:attributes]` at
  creation is preferred over `Span.set_attribute/3` later —
  samplers can only consider information already present during
  creation.
  """
  @spec start_span(name :: String.t(), opts :: start_opts()) :: Otel.Trace.SpanContext.t()
  def start_span(name, opts \\ []) do
    Otel.Trace.Tracer.start_span(Otel.Ctx.current(), name, opts)
  end

  @doc """
  **Application** (OTel API MUST) — Span Creation with an
  explicit parent context (`trace/api.md` L378-L414).

  Per spec L391-L392, only a full Context is accepted as the
  parent — not a raw Span or SpanContext. Per spec L382 the
  newly created span is not set as the current span.
  """
  @spec start_span(ctx :: Otel.Ctx.t(), name :: String.t(), opts :: start_opts()) ::
          Otel.Trace.SpanContext.t()
  def start_span(ctx, name, opts) do
    Otel.Trace.Tracer.start_span(ctx, name, opts)
  end

  @doc """
  **Application** (OTel API MAY) — closure-form span creation
  using the implicit (process-local) context as parent
  (`trace/api.md` L385).

  Starts the span, makes it the current span for the closure,
  records any exception that escapes, ends the span, and
  detaches the context.
  """
  @spec with_span(
          name :: String.t(),
          opts :: start_opts(),
          fun :: (Otel.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  def with_span(name, opts \\ [], fun) do
    Otel.Trace.Tracer.with_span(Otel.Ctx.current(), name, opts, fun)
  end

  @doc """
  **Application** (OTel API MAY) — same as `with_span/3` but
  with an explicit parent context (`trace/api.md` L385).
  """
  @spec with_span(
          ctx :: Otel.Ctx.t(),
          name :: String.t(),
          opts :: start_opts(),
          fun :: (Otel.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  def with_span(ctx, name, opts, fun) do
    Otel.Trace.Tracer.with_span(ctx, name, opts, fun)
  end

  # --- Manual active-span management ---

  @doc """
  **Application** (OTel API MAY) — set `span_ctx` as the
  currently active span and return a detach token
  (`trace/api.md` L384-L386 *"this functionality MAY be offered
  additionally as a separate operation"*).

  For most call sites, prefer `with_span/3,4` — it handles
  attach, exception recording, detach, and `end_span` in a
  single closure-safe call. `make_current/1` exists for
  cases where the active span must outlive a single
  function scope — async handoff, test fixtures, or
  non-closure interop.

  Callers MUST pair each `make_current/1` with a `detach/1`
  on every exit path. Use `try/after` or equivalent to
  guarantee revert on exceptions:

      token = Otel.Trace.make_current(span_ctx)
      try do
        # ... work ...
      after
        Otel.Trace.detach(token)
      end

  Internally composes `set_current_span/2` with
  `Otel.Ctx.attach/1`. Stacked calls are LIFO — nested
  `make_current`/`detach` pairs restore the prior active
  span in reverse order.
  """
  @spec make_current(span_ctx :: Otel.Trace.SpanContext.t()) :: Otel.Ctx.t()
  def make_current(%Otel.Trace.SpanContext{} = span_ctx) do
    old_ctx = Otel.Ctx.current()
    new_ctx = set_current_span(old_ctx, span_ctx)
    Otel.Ctx.attach(new_ctx)
  end

  @doc """
  **Application** (OTel API MAY) — revert a `make_current/1`
  call using the token it returned (`trace/api.md` L384-L386).

  Restores the previous ambient context, undoing the most
  recent `make_current/1` whose token is passed. Delegates
  to `Otel.Ctx.detach/1`.
  """
  @spec detach(token :: Otel.Ctx.t()) :: :ok
  def detach(token), do: Otel.Ctx.detach(token)

  @doc """
  **Application** (introspection) — Returns the resource resolved
  from the `:otel` `:resource` `Application` env, or
  `Otel.Resource.default/0` when no env is set.
  """
  @spec resource() :: Otel.Resource.t()
  def resource, do: Otel.Resource.from_app_env()
end
