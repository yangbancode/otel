defmodule Otel.API.Logs.Logger.Noop do
  @moduledoc """
  No-op `Logger` implementation (OTel `logs/noop.md`
  §Logger, Status: **Stable**).

  Used when no SDK is installed. Per `noop.md` L33-L35 a
  No-Op component:

  - MUST NOT hold any configuration or operational state
  - MUST accept every parameter a real implementation would
  - MUST NOT validate any argument it receives
  - MUST NOT return any non-empty error or log any message

  All emit calls silently return `:ok`; `enabled?/2` always
  returns `false` per `noop.md` L62.

  All functions are safe for concurrent use.

  ## Public API

  | Function | Role |
  |---|---|
  | `emit/3` | **SDK** (Noop implementation) — Emit LogRecord (`noop.md` L57-L58) |
  | `enabled?/2` | **SDK** (Noop implementation) — Enabled (`noop.md` L62) |

  ## References

  - OTel Logs API No-Op: `opentelemetry-specification/specification/logs/noop.md`
  - OTel Logs API §Emit a LogRecord: `opentelemetry-specification/specification/logs/api.md` L111-L131
  - OTel Logs API §Enabled: `opentelemetry-specification/specification/logs/api.md` L133-L154
  """

  @behaviour Otel.API.Logs.Logger

  @doc """
  **SDK** (Noop implementation) — "Emit LogRecord" for a
  No-Op Logger (`logs/noop.md` L57-L58).

  Silently discards the log record. Per `noop.md` L33-L35 no
  validation is performed on `logger`, `ctx`, or
  `log_record` — any shape of log record is accepted. Always
  returns `:ok`.
  """
  @impl true
  @spec emit(
          logger :: Otel.API.Logs.Logger.t(),
          ctx :: Otel.API.Ctx.t(),
          log_record :: Otel.API.Logs.Logger.log_record()
        ) :: :ok
  def emit(_logger, _ctx, _log_record), do: :ok

  @doc """
  **SDK** (Noop implementation) — "Enabled" for a No-Op
  Logger (`logs/noop.md` L62 *"MUST always return `false`"*).

  Always returns `false` — a no-op logger is by definition
  not enabled for any severity, event name, or context.
  """
  @impl true
  @spec enabled?(logger :: Otel.API.Logs.Logger.t(), opts :: Otel.API.Logs.Logger.enabled_opts()) ::
          boolean()
  def enabled?(_logger, _opts), do: false
end
