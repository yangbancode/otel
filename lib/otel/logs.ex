defmodule Otel.Logs do
  @moduledoc """
  Shared types for the OTel Logs API data model
  (`logs/data-model.md` §Severity Fields L234-L363).

  Referenced by `Otel.Logs.Logger.log_record` and
  `enabled_opt`. No behavioural functions — source → OTel
  conversion is each bridge's responsibility (see e.g.
  `Otel.LoggerHandler`).

  ## Public API

  | Type | Role |
  |---|---|
  | `t:severity_number/0` | **Application** (data model) — OTel SeverityNumber value domain |
  | `t:severity_level/0` | **Application** (data model) — source-native severity text |

  ## References

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
end
