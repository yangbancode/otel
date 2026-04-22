defmodule Otel.API.Logs.Severity do
  @moduledoc """
  Severity types and mappings for the OTel Logs data model
  (OTel `logs/data-model.md` §Severity Fields L234-L363;
  §Mapping of `SeverityNumber` L273-L296; §Displaying
  Severity L334-L363; Appendix B Syslog row
  `data-model-appendix.md` L806-L818; Status: **Stable**).

  Unifies two related representations of severity:

  - `t:severity_number/0` — the OTel `SeverityNumber` value
    domain (`0..24`), carried by
    `Otel.API.Logs.Logger.log_record` and
    `Otel.API.Logs.Logger.enabled_opt`.
  - `t:severity_level/0` — the Elixir / Erlang `:logger`
    severity level atom (the 8 RFC 5424 Syslog severities as
    lowercased atoms). Re-exports `:logger.level/0` —
    see kernel `9.2.4.11` `src/logger.erl` L81-L82.

  And the conversion between them via `to_number/1` per
  spec Appendix B Syslog row.

  ## Why both types live together

  The Logs data model exposes severity through two surfaces
  simultaneously:

  1. On the wire and in-memory LogRecord, the authoritative
     representation is `SeverityNumber` — the normalized
     `0..24` value.
  2. At the source side (Elixir / Erlang), the idiomatic
     representation is a `:logger` level atom (`:info`,
     `:error`, etc.).

  Log bridges (starting with `Otel.Logger.Handler`) need
  both: `severity_level()` to type their input,
  `severity_number()` to populate
  `log_record.severity_number`, and `to_number/1` to cross
  the gap. Grouping them here keeps the three concerns
  discoverable in one module and prevents the mapping table
  from being re-derived in each bridge —
  `opentelemetry-erlang`'s Syslog mapping in
  `otel_otlp_logs.erl` L238-L253 already shows the same
  shape.

  ## Naming

  The type names repeat the module name (`Severity.severity_number`,
  `Severity.severity_level`) rather than the shorter
  `Severity.number` / `Severity.level` because `number` is
  an Elixir built-in type (`integer() | float()`) that the
  compiler forbids shadowing. The `severity_*` prefix also
  matches the OTel spec's own field naming
  (`SeverityNumber`, `SeverityText`), so the redundancy is
  mild and the module feels consistent with the spec
  vocabulary.

  ## Public API

  | Function | Role |
  |---|---|
  | `to_number/1` | **Application** (Convenience) — `:logger` level → OTel SeverityNumber |

  ## References

  - OTel Logs §SeverityNumber: `opentelemetry-specification/specification/logs/data-model.md` L246-L271
  - OTel Logs §Mapping of SeverityNumber: `opentelemetry-specification/specification/logs/data-model.md` L273-L296
  - OTel Logs Appendix B (example mappings): `opentelemetry-specification/specification/logs/data-model-appendix.md` L806-L818
  - RFC 5424 §6.2.1 (severity codes): <https://www.rfc-editor.org/rfc/rfc5424>
  - Erlang `:logger.level/0`: kernel `src/logger.erl` L81-L82
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
  """
  @type severity_level :: :logger.level()

  @doc """
  **Application** (Convenience) — map an Elixir / Erlang
  `:logger` level atom to an OTel `SeverityNumber` per spec
  Appendix B Syslog row (`data-model-appendix.md`
  L806-L818).

  | `:logger` level | SeverityNumber | OTel short name |
  |---|---|---|
  | `:emergency` | 21 | FATAL |
  | `:alert` | 19 | ERROR3 |
  | `:critical` | 18 | ERROR2 |
  | `:error` | 17 | ERROR |
  | `:warning` | 13 | WARN |
  | `:notice` | 10 | INFO2 |
  | `:info` | 9 | INFO |
  | `:debug` | 5 | DEBUG |

  Distinct `:logger` levels within the same SeverityNumber
  range (e.g. `:error` vs `:critical` vs `:alert` in ERROR)
  are assigned different numbers per spec L280-L283,
  preserving their relative ordering.
  """
  @spec to_number(level :: severity_level()) :: severity_number()
  def to_number(:emergency), do: 21
  def to_number(:alert), do: 19
  def to_number(:critical), do: 18
  def to_number(:error), do: 17
  def to_number(:warning), do: 13
  def to_number(:notice), do: 10
  def to_number(:info), do: 9
  def to_number(:debug), do: 5
end
