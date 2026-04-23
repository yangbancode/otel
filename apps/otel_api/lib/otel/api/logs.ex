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
  | `t:severity_level/0` | **Application** (data model) — severity level string (`:logger.level/0` stringified) |

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
  A severity level as a **string** — the
  `Atom.to_string/1` form of an Elixir / Erlang
  `:logger.level/0` atom.

  Valid values: `"emergency"`, `"alert"`, `"critical"`,
  `"error"`, `"warning"`, `"notice"`, `"info"`, `"debug"`.

  String (not atom) because the Logs API carries severity
  on the "text" surface as a string —
  `log_record.severity_text` is `String.t()` per
  `logs/data-model.md` L238-L244. Bridges receiving
  `:logger.level/0` atoms call `Atom.to_string/1` at the
  boundary to produce values of this type.

  Elixir typespecs cannot express a literal-string union,
  so the type is declared as `String.t()` — the valid-value
  list here is documentation, not Dialyzer-enforced. (For
  Dialyzer-enforced level values stay on `:logger.level/0`
  atoms upstream of stringification.)

  ### Why `:logger.level/0` — not RFC 5424 keywords

  RFC 5424 §6.2.1 defines the 8 Syslog severities using
  keywords like `Emergency`, `Alert`, `Informational`,
  `Debug`. Erlang `:logger` chose **short atom forms** for
  its `level/0` type (`:info`, not `:informational`), and
  `Atom.to_string/1` preserves that short form. The string
  `"info"` here is Erlang's `:info` stringified — **not**
  the RFC 5424 keyword `"Informational"` lowercased.

  Does **not** include `"all"` / `"none"`; those are
  `:logger`'s filter/threshold configuration values (not in
  `:logger.level/0`) and never appear on a log event.
  """
  @type severity_level :: String.t()
end
