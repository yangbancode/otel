defmodule Otel.API.Trace.Tracer do
  @moduledoc """
  Tracer behaviour (spec `trace/api.md` §Tracer, Status:
  **Stable**, L184-L219).

  A Tracer is responsible for creating `Span`s (spec L186).
  Configuration (sampler, limits, scope, processors) belongs to
  the `TracerProvider`, not the Tracer itself (spec L188-L189).

  Represented as a `{module, config}` tuple where `module`
  implements this behaviour. Configuration is stored in the tuple
  at creation time so span creation needs no GenServer call.

  Spec requirements met:

  - **MUST** Create a new Span (L193-L195) → `start_span/4`
  - **SHOULD** Report if Enabled (L197-L199) → `enabled?/2`

  The `Enabled` API is in **Development** status (L203). Per
  L208-L210 *"the API MUST be structured in a way for parameters
  to be added"* — `enabled?/2` accepts an `enabled_opts` keyword
  list for forward-compatibility. Per L216-L219 the return value
  is not static and may change over time; callers SHOULD invoke
  `enabled?/2` each time before creating a Span to have the
  most up-to-date response.

  All functions are safe for concurrent use.

  ## Public API

  | Function | Role |
  |---|---|
  | `start_span/4` | **OTel API MUST** (§Tracer) |
  | `enabled?/2` | **OTel API SHOULD** (§Enabled, Development) |

  ## References

  - OTel Trace API §Tracer: `opentelemetry-specification/specification/trace/api.md` L184-L219
  """

  @typedoc """
  A tracer value — a `{module, config}` tuple where `module`
  implements `Otel.API.Trace.Tracer` and `config` carries
  tracer-specific configuration (sampler, id generator, limits,
  scope, processors).

  Per spec L188-L189 configuration is the TracerProvider's
  responsibility; obtain a tracer via
  `Otel.API.Trace.TracerProvider` rather than constructing the
  tuple directly.
  """
  @type t :: {module(), term()}

  @typedoc """
  Options accepted by `enabled?/2`.

  Per spec `trace/api.md` L208-L210 the Trace API does **not**
  define common parameters for `Enabled`. Since `Otel.API.Trace`
  is the API layer — independent of any specific SDK
  implementation — concrete keys cannot be enumerated here
  without prematurely coupling to an implementation.

  The type is intentionally open (`keyword()`) at the API layer.
  Each SDK implementation may interpret any keyword it
  recognises and ignore the rest; implementations SHOULD
  document their accepted keys in their own module typedoc.

  Contrast with `Otel.API.Logs.Logger`'s `enabled_opt` and
  `Otel.API.Metrics.Instrument`'s `enabled_opt`, where the OTel
  spec itself defines the common keys at the API level —
  enumeration is appropriate there because it mirrors a spec
  contract, not an SDK assumption.
  """
  @type enabled_opts :: keyword()

  @doc """
  **OTel API MUST** — "Create a new Span" (`trace/api.md`
  L193-L195).

  Starts a new span and returns its `SpanContext`.

  Options are documented by `Otel.API.Trace.Span.start_opts/0`.
  """
  @callback start_span(
              ctx :: Otel.API.Ctx.t(),
              tracer :: t(),
              name :: String.t(),
              opts :: Otel.API.Trace.Span.start_opts()
            ) ::
              Otel.API.Trace.SpanContext.t()

  @doc """
  **OTel API SHOULD** — "Enabled" (`trace/api.md` L201-L219,
  Status: **Development**).

  Returns whether the tracer is enabled for the given arguments.
  Per spec L208-L210 `opts` exists for future extensibility —
  currently no required parameters.

  Per spec L216-L219 **the return value is not static**; it can
  change over time. Instrumentation authors SHOULD call this
  function each time before creating a Span to have the
  most up-to-date response.
  """
  @callback enabled?(tracer :: t(), opts :: enabled_opts()) :: boolean()
end
