defmodule Otel.Logs do
  @moduledoc """
  Logs API facade — emit entry point and shared types
  (`logs/api.md` §LoggerProvider L62-L97 + `logs/data-model.md`
  §Severity Fields L234-L363).

  Minikube has no plugin ecosystem, so the spec's
  LoggerProvider + Logger entities collapse to a single
  hardcoded identity. The facade exposes `emit/1,2` directly
  — there's no Logger handle to obtain via `get_logger/0`
  first; call `Otel.Logs.emit/1,2` directly.

  ## Public API

  | Function | Role |
  |---|---|
  | `emit/1`, `emit/2` | **Application** (OTel API MUST) — `logs/api.md` L111-L131 |

  ## Data model types

  | Type | Role |
  |---|---|
  | `t:severity_number/0` | **Application** (data model) — OTel SeverityNumber value domain |
  | `t:severity_level/0` | **Application** (data model) — source-native severity text |

  ## References

  - OTel Logs API §Logger: `opentelemetry-specification/specification/logs/api.md`
  - OTel Logs §Severity Fields: `opentelemetry-specification/specification/logs/data-model.md` L234-L363
  - Erlang `:logger.level/0`: kernel `src/logger.erl` L81-L82
  - RFC 5424 §6.2.1: <https://www.rfc-editor.org/rfc/rfc5424>
  """

  @typedoc """
  An OTel `SeverityNumber` value (`logs/data-model.md` §Field:
  `SeverityNumber` L246-L271).

  `0` is the "unspecified" sentinel (L271); `1..24` span six
  ranges of four short names (TRACE, DEBUG, INFO, WARN, ERROR,
  FATAL) per §Displaying Severity L334-L363.
  """
  @type severity_number :: 0..24

  @typedoc """
  A severity level string — the source's native text per
  `logs/data-model.md` L240-L241.

  Not constrained to any vocabulary. Each source spells its
  levels differently — `:logger` → `"info"`, RFC 5424 →
  `"Informational"`, Log4j → `"INFO"`. For uniform rendering,
  derive from `severity_number` via §Displaying Severity
  L334-L363 (OTel short names like `FATAL`, `ERROR3`, `INFO`).

  Declared as `String.t()` because Elixir typespecs can't
  express literal-string unions.
  """
  @type severity_level :: String.t()

  @doc """
  **Application** (OTel API MUST) — Emit a LogRecord using the
  implicit (process-local) context (`logs/api.md` L111-L131).
  """
  @spec emit(log_record :: Otel.Logs.LogRecord.t()) :: :ok
  def emit(log_record \\ %Otel.Logs.LogRecord{}) do
    Otel.Logs.Logger.emit(Otel.Ctx.current(), log_record)
  end

  @doc """
  **Application** (OTel API MUST) — Emit a LogRecord with an
  explicit context (`logs/api.md` L111-L131).
  """
  @spec emit(ctx :: Otel.Ctx.t(), log_record :: Otel.Logs.LogRecord.t()) :: :ok
  def emit(ctx, log_record) do
    Otel.Logs.Logger.emit(ctx, log_record)
  end
end
