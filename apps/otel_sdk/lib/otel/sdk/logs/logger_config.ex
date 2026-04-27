defmodule Otel.SDK.Logs.LoggerConfig do
  @moduledoc """
  Per-Logger configuration computed by a `LoggerConfigurator`
  (`logs/sdk.md` §LoggerConfig L183-L221, **Status: Development**).

  Three filter knobs the SDK applies before dispatching a
  `LogRecord` to processors:

  | Field | Default | Spec |
  |---|---|---|
  | `enabled` | `true` | L190-L196 — *"If a Logger is disabled, it MUST behave equivalently to No-op Logger"* |
  | `minimum_severity` | `0` | L198-L206 — *"if specified (i.e. not 0) and is less than the configured `minimum_severity`, the log record MUST be dropped"* |
  | `trace_based` | `false` | L208-L217 — *"log records associated with unsampled traces MUST be dropped"* |

  ## How a Logger gets its config

  `Otel.SDK.Logs.LoggerProvider` accepts a
  `:logger_configurator` start option — a function
  `(Otel.API.InstrumentationScope.t() -> t())`. The function is
  invoked once per `get_logger/2` call, and the resulting
  `LoggerConfig` is stored on the Logger handle. When no
  configurator is supplied, every Logger gets the
  defaults above (i.e. enabled, no minimum severity, not
  trace-based).

  The default configurator is the identity-returning function
  `&__MODULE__.default/1`, suitable as a starting point for
  user-supplied configurators that want to layer rules on top
  of the defaults.

  ## Filter ordering at emit time

  `Otel.SDK.Logs.Logger.emit/3` applies the filters in the
  order spec L243-L252 prescribes:

  1. `enabled == false` → drop (no further work).
  2. Minimum severity (record's `severity_number != 0` and
     `< minimum_severity`).
  3. Trace-based (record's `span_id != 0` and `trace_flags`
     SAMPLED bit unset).

  Each step is short-circuited.

  ## Filter ordering at `Enabled?` time

  `Otel.SDK.Logs.Logger.enabled?/2` mirrors the same checks
  using the `:severity_number` / `:ctx` from `enabled_opts/0`,
  combining them with the spec L256-L268 conditions on the
  processor list.

  ## Public API

  | Function | Role |
  |---|---|
  | `default/1` | **SDK** (default configurator) |

  ## References

  - OTel Logs SDK §LoggerConfig: `opentelemetry-specification/specification/logs/sdk.md` L183-L221
  - OTel Logs SDK §Configuration / LoggerConfigurator: same file L83-L114
  - Filter rules at emit / Enabled: same file L243-L268
  """

  @typedoc """
  Per-Logger config struct. All three fields default to the
  values spec L190-L217 mandates.
  """
  @type t :: %__MODULE__{
          enabled: boolean(),
          minimum_severity: Otel.API.Logs.severity_number(),
          trace_based: boolean()
        }

  defstruct enabled: true,
            minimum_severity: 0,
            trace_based: false

  @typedoc """
  A `LoggerConfigurator` per spec L107-L114 — a function that
  receives the InstrumentationScope of the Logger being
  created and returns the `LoggerConfig` it should use.

  The function MUST be cheap and side-effect free per spec
  L121-L124 (*"it is important that it returns / quickly."*).
  """
  @type configurator :: (Otel.API.InstrumentationScope.t() -> t())

  @doc """
  **SDK** (default configurator) — Returns the default
  `LoggerConfig` for any scope. Used when the LoggerProvider
  was started without a `:logger_configurator` option.
  """
  @spec default(scope :: Otel.API.InstrumentationScope.t()) :: t()
  def default(_scope), do: %__MODULE__{}
end
