defmodule Otel.API.Logs do
  @moduledoc """
  Shared types for the OTel Logs API data model
  (`logs/data-model.md` §Severity Fields L234-L363;
  Status: **Stable**).

  Holds the severity-related types that multiple Logs API
  surfaces reference — `Otel.API.Logs.Logger.log_record`
  carries `severity_number()`, and
  `Otel.API.Logs.Logger.enabled_opt` takes
  `severity_number()` as an option key.

  No behavioural functions live here. Source-format → OTel
  conversion (e.g. `:logger.level()` → `severity_number()`
  per Appendix B Syslog row) is each bridge's own
  responsibility — `Otel.Logger.Handler` applies Appendix B
  internally. Other bridges can map from their own source
  severity representation into `severity_number()` the same
  way.

  ## Public API

  | Type | Role |
  |---|---|
  | `t:severity_number/0` | **Application** (data model) — OTel SeverityNumber value domain |
  | `t:severity_level/0` | **Application** (data model) — severity level string per spec L240-L241 (source-native, not forced to any vocabulary) |

  ## References

  - OTel Logs §Severity Fields: `opentelemetry-specification/specification/logs/data-model.md` L234-L363
  - OTel Logs §SeverityNumber: `opentelemetry-specification/specification/logs/data-model.md` L246-L271
  - Erlang `:logger.level/0`: kernel `src/logger.erl` L81-L82
  - RFC 5424 §6.2.1 (severity codes): <https://www.rfc-editor.org/rfc/rfc5424>
  """

  @typedoc """
  An OpenTelemetry `SeverityNumber` value (`logs/data-model.md`
  §Field: `SeverityNumber` L246-L271).

  `0` is the spec's "unspecified" sentinel (L271); `1..24` are
  the assigned severity values across six ranges of four short
  names each (TRACE, DEBUG, INFO, WARN, ERROR, FATAL) — see
  §Displaying Severity L334-L363.
  """
  @type severity_number :: 0..24

  @typedoc """
  A severity level string — the source's native text
  representation per `logs/data-model.md` §Field:
  `SeverityText` L238-L244 *"the original string
  representation of the severity as it is known at the
  source"*.

  ### Not forced to any specific vocabulary

  This type does **not** constrain callers to RFC 5424
  keywords, Erlang `:logger.level/0` stringified forms, or
  any other single convention. Per spec L240-L241 the
  value is whatever the source natively uses. Examples
  across common log sources:

  | Source | Native text examples |
  |---|---|
  | Erlang / Elixir `:logger` | `"emergency"`, `"alert"`, `"critical"`, `"error"`, `"warning"`, `"notice"`, `"info"`, `"debug"` (lowercase short atoms) |
  | RFC 5424 Syslog keywords | `"Emergency"`, `"Alert"`, `"Critical"`, `"Error"`, `"Warning"`, `"Notice"`, `"Informational"`, `"Debug"` (capitalized full forms) |
  | Log4j | `"TRACE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"FATAL"` (uppercase short forms) |
  | Python `logging` | `"DEBUG"`, `"INFO"`, `"WARNING"`, `"ERROR"`, `"CRITICAL"` |
  | Custom / proprietary | whatever the source defines |

  Note that the same underlying severity can surface as
  different strings — `:logger`'s `"info"` and RFC 5424's
  `"Informational"` are both valid representations of
  SeverityNumber 9. Our `Otel.Logger.Handler` uses the
  `:logger` lowercase form because that's **its** source's
  native representation; it is **not** a project-wide
  convention.

  Consumers of `log_record.severity_text` **MUST NOT**
  assume a particular vocabulary — treat it as opaque text
  from the source. If a uniform representation is needed
  (for display, filtering, etc.), derive it from
  `severity_number` using the §Displaying Severity table
  (`logs/data-model.md` L334-L363) — the OTel short names
  (`FATAL`, `ERROR3`, `INFO`, …) exist for exactly that
  purpose and are independent of whatever text the source
  happened to use.

  ### Why declared as `String.t()`

  Elixir / Erlang typespecs cannot express a literal-string
  union — the compiler rejects `"info" | "debug"` as
  *"unexpected expression in typespec"*. Binary content is
  not representable as a literal type the way atoms or
  integers are. So the declared type is the broadest
  possible (`String.t()`), and the vocabulary examples
  above are documentation rather than Dialyzer-enforced
  constraints. Bridges that emit a specific subset (as
  `Otel.Logger.Handler` does) document their own values in
  their module docs.

  `"all"` / `"none"` never appear on log events —
  `:logger` reserves those for filter/threshold
  configuration and they're not in `:logger.level/0` —
  but again this type does not enforce that because other
  sources may have their own reserved words.
  """
  @type severity_level :: String.t()
end
