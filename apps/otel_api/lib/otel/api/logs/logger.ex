defmodule Otel.API.Logs.Logger do
  @moduledoc """
  `Logger` behaviour and dispatch facade (OTel
  `logs/api.md` §Logger L99-L155; Status: **Stable**; §Enabled
  is **Development**).

  A `Logger` emits `LogRecord`s. It is represented as a
  `{module, config}` tuple where `module` implements this
  behaviour — the same pattern used by `Otel.API.Trace.Tracer`.
  Per spec L188-L189 (trace) and by analogy for logs,
  configuration (resource, log limits, processors) belongs to
  the `LoggerProvider`, not the Logger itself; obtain a
  Logger via `Otel.API.Logs.LoggerProvider.get_logger/1`
  rather than constructing the tuple directly.

  All functions are safe for concurrent use (spec L173-L174).

  ## Public API

  | Function | Role |
  |---|---|
  | `emit/2` | **Application** (OTel API MUST) — Emit via implicit context (L121-L123) |
  | `emit/3` | **Application** (OTel API MUST) — Emit via explicit context (L119-L121) |
  | `enabled?/2` | **Application** (OTel API SHOULD) — Enabled dispatch |
  | `@callback emit/3` | **SDK** (OTel API MUST) — Emit a LogRecord (L111-L131) |
  | `@callback enabled?/2` | **SDK** (OTel API SHOULD) — Enabled (L133-L154) |

  ## References

  - OTel Logs API §Logger: `opentelemetry-specification/specification/logs/api.md` L99-L155
  - OTel Logs API §Concurrency: `opentelemetry-specification/specification/logs/api.md` L167-L176
  - OTel Logs API No-Op: `opentelemetry-specification/specification/logs/noop.md` (fallback when no SDK is installed)
  """

  use Otel.API.Common.Types

  @typedoc """
  A logger value — a `{module, config}` tuple where `module`
  implements the `Otel.API.Logs.Logger` behaviour and
  `config` carries logger-specific configuration (resource,
  log limits, processors, scope).

  Per spec L101-L102 configuration is the LoggerProvider's
  responsibility; obtain a logger via
  `Otel.API.Logs.LoggerProvider.get_logger/1` rather than
  constructing the tuple directly.
  """
  @type t :: {module(), term()}

  @typedoc """
  Parameters accepted by `emit/3` and the `emit/3` callback,
  mirroring §Emit a LogRecord (`logs/api.md` L111-L131).

  All fields are optional — omit the key to signal "missing"
  per spec's field-level guidance (e.g. Timestamp
  `data-model.md` L185-L187 *"This field is optional, it may
  be missing"*). Spec does **not** treat `null` as a
  distinct third state; `optional(:key) => value()` is the
  spec-aligned representation of "either present with a
  proper value or absent".

  - `:timestamp` — Unix epoch **nanoseconds** (OTLP
    `time_unix_nano`); see `data-model.md#field-timestamp`
    (L180-L187)
  - `:observed_timestamp` — Unix epoch **nanoseconds**
    (OTLP `time_unix_nano`); see
    `data-model.md#field-observedtimestamp` (L189-L204)
  - `:severity_number` — `0..24` per
    `data-model.md#field-severitynumber` (L260-L271); note
    that `0` is spec's "unspecified" sentinel — do **not**
    use a separate absent/null value to represent it
  - `:severity_text` — `data-model.md#field-severitytext`
  - `:body` — `primitive_any/0` per OTLP `AnyValue`, which
    explicitly allows language-idiomatic `null` values
    (`common.md` L49-L50) — this is the one field where
    `nil` is spec-permitted
  - `:attributes` — `data-model.md#field-attributes`
  - `:event_name` — `data-model.md#field-eventname`
  - `:exception` — MAY accept per `logs/api.md` L131

  The Context parameter is handled separately — passed as
  the second argument to `emit/3` rather than embedded in
  the log record map (spec L119-L121: the Context SHOULD be
  optional, with current Context substituted when absent).
  """
  @type log_record :: %{
          optional(:timestamp) => integer(),
          optional(:observed_timestamp) => integer(),
          optional(:severity_number) => Otel.API.Logs.SeverityNumber.t(),
          optional(:severity_text) => String.t(),
          optional(:body) => primitive_any(),
          optional(:attributes) => %{String.t() => primitive() | [primitive()]},
          optional(:event_name) => String.t(),
          optional(:exception) => Exception.t()
        }

  @typedoc """
  One option accepted by `enabled?/2`, per §Enabled
  (`logs/api.md` L137-L142):

  - `:severity_number` — severity the caller would emit
    (0..24, L141)
  - `:event_name` — event name the caller would emit (L142)
  - `:ctx` — evaluation context (L137-L140; defaults to
    `Otel.API.Ctx.current/0` when omitted)

  Unlike `Otel.API.Trace.Tracer.enabled_opt/0` which is left
  open (`keyword()`) because the Trace spec does not define
  common keys, Logs §Enabled enumerates these three keys at
  the API level — enumeration is appropriate here because it
  mirrors a spec contract, not an SDK assumption
  (`.claude/rules/code-conventions.md` §Layer independence).
  """
  @type enabled_opt ::
          {:severity_number, Otel.API.Logs.SeverityNumber.t()}
          | {:event_name, String.t()}
          | {:ctx, Otel.API.Ctx.t()}

  @typedoc "A keyword list of `enabled_opt/0` values."
  @type enabled_opts :: [enabled_opt()]

  # --- Application dispatch ---

  @doc """
  **Application** (OTel API MUST) — Emit a LogRecord using
  the implicit (process-local) context (`logs/api.md`
  L119-L123 *"When implicit Context is supported, then this
  parameter SHOULD be optional and if unspecified then MUST
  use current Context"*).

  Injects `Otel.API.Ctx.current/0` as the context and
  delegates to the Logger's `emit/3` callback. `log_record`
  defaults to the empty map so all fields are truly optional
  at the call site.
  """
  @spec emit(logger :: t(), log_record :: log_record()) :: :ok
  def emit({module, _} = logger, log_record \\ %{}) do
    ctx = Otel.API.Ctx.current()
    module.emit(logger, ctx, log_record)
  end

  @doc """
  **Application** (OTel API MUST) — Emit a LogRecord with
  an explicit context (`logs/api.md` L119-L121).

  Delegates directly to the Logger's `emit/3` callback
  without context injection. Use when the caller wants a
  specific `ctx` instead of the process-local current one.
  """
  @spec emit(logger :: t(), ctx :: Otel.API.Ctx.t(), log_record :: log_record()) :: :ok
  def emit({module, _} = logger, ctx, log_record) do
    module.emit(logger, ctx, log_record)
  end

  @doc """
  **Application** (OTel API SHOULD) — Enabled dispatch
  (`logs/api.md` L133-L154).

  Delegates to the Logger's `enabled?/2` callback after
  ensuring `:ctx` is set. When `opts` does not supply
  `:ctx`, the current context is injected per spec
  L137-L140 *"if unspecified then MUST use current
  Context"*.

  Per spec L148-L153 the result is **not static** — it
  reflects sampling/configuration state at the moment of
  call and may change over time. Instrumentation authors
  SHOULD call this each time before emitting to have the
  most up-to-date answer.
  """
  @spec enabled?(logger :: t(), opts :: enabled_opts()) :: boolean()
  def enabled?({module, _} = logger, opts \\ []) do
    opts =
      case Keyword.has_key?(opts, :ctx) do
        true -> opts
        false -> Keyword.put(opts, :ctx, Otel.API.Ctx.current())
      end

    module.enabled?(logger, opts)
  end

  # --- SDK callbacks ---

  @doc """
  **SDK** (OTel API MUST) — "Emit a LogRecord"
  (`logs/api.md` L111-L131).

  Emits the given `log_record` to the processing pipeline.
  All fields of `log_record` are optional per L117-L131; the
  caller may supply any subset including the empty map.

  Per spec L119-L121 the `ctx` parameter is the Context
  associated with the LogRecord. The API-layer dispatch
  functions (`emit/2`, `emit/3`) handle the implicit /
  explicit context split; this callback always receives an
  explicit context.
  """
  @callback emit(
              logger :: t(),
              ctx :: Otel.API.Ctx.t(),
              log_record :: log_record()
            ) :: :ok

  @doc """
  **SDK** (OTel API SHOULD) — "Enabled" (`logs/api.md`
  L133-L154, Status: **Development**).

  Returns whether the logger is enabled for the supplied
  `opts`. Per L148-L153 the returned value is **not static**
  — it can change over time as configuration or sampling
  state evolves. Instrumentation authors SHOULD call this
  function each time before they
  [emit a LogRecord](#emit-a-logrecord) to have the most
  up-to-date response.

  `opts` keys are spec-defined (L137-L142): `:ctx`,
  `:severity_number`, `:event_name`. The API-layer
  dispatch (`enabled?/2`) fills in `:ctx` from the current
  context when omitted per L137-L140.
  """
  @callback enabled?(
              logger :: t(),
              opts :: enabled_opts()
            ) :: boolean()
end
