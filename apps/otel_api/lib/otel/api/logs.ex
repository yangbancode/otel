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
  | `t:severity_level/0` | **Application** (data model) — `:logger.level/0` re-export for bridge inputs |

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
  An Elixir / Erlang `:logger` severity level atom — the
  8 RFC 5424 Syslog severities as lowercased atoms
  (`:emergency`, `:alert`, `:critical`, `:error`,
  `:warning`, `:notice`, `:info`, `:debug`).

  Re-exports `:logger.level/0` directly; does **not**
  include `:all` / `:none`, which `:logger` reserves for
  filter/threshold configuration and never appear on a
  log event.

  Consumed by `:logger`-based bridges as the input type of
  their source → `severity_number/0` conversion.
  """
  @type severity_level :: :logger.level()
end
