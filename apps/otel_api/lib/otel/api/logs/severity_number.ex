defmodule Otel.API.Logs.SeverityNumber do
  @moduledoc """
  Helpers for OpenTelemetry `SeverityNumber` (OTel
  `logs/data-model.md` §Field: `SeverityNumber` L246-L271;
  §Mapping of `SeverityNumber` L273-L296; §Displaying Severity
  L334-L363; Status: **Stable**).

  The `SeverityNumber` value domain is `0..24`. Spec L271
  designates `0` as the "unspecified" sentinel; `1..24` are
  assigned to six ranges of four short names each:

  | Range | Short names |
  |---|---|
  | `1..4` | TRACE, TRACE2, TRACE3, TRACE4 |
  | `5..8` | DEBUG, DEBUG2, DEBUG3, DEBUG4 |
  | `9..12` | INFO, INFO2, INFO3, INFO4 |
  | `13..16` | WARN, WARN2, WARN3, WARN4 |
  | `17..20` | ERROR, ERROR2, ERROR3, ERROR4 |
  | `21..24` | FATAL, FATAL2, FATAL3, FATAL4 |

  Each source format (Syslog, WinEvtLog, Log4j, Zap, java.util.logging,
  .NET, …) has its own recommended SeverityNumber mapping table
  in spec Appendix B (`data-model-appendix.md` L806-L818). This
  module exposes one conversion function per format; bridges add
  new functions here as they're needed rather than re-deriving
  the mapping each time. Right now only Syslog is covered — that
  's what `Otel.Logger.Handler` needs because Elixir / Erlang
  `:logger.level/0` atoms are lowercased RFC 5424 Syslog level
  names.

  ## Public API

  | Function | Role |
  |---|---|
  | `from_syslog_level/1` | **Application** (Convenience) — RFC 5424 Syslog level → SeverityNumber (Appendix B L806-L818) |

  ## References

  - OTel Logs §SeverityNumber: `opentelemetry-specification/specification/logs/data-model.md` L246-L271
  - OTel Logs §Mapping of SeverityNumber: `opentelemetry-specification/specification/logs/data-model.md` L273-L296
  - OTel Logs Appendix B (example mappings): `opentelemetry-specification/specification/logs/data-model-appendix.md` L806-L818
  - RFC 5424 Syslog: <https://datatracker.ietf.org/doc/html/rfc5424>
  """

  @typedoc """
  An OpenTelemetry `SeverityNumber` value (`logs/data-model.md`
  L246-L271).

  `0` is the spec's "unspecified" sentinel (L271); `1..24` are
  the assigned severity values across six ranges of four short
  names each (TRACE, DEBUG, INFO, WARN, ERROR, FATAL).
  """
  @type t :: 0..24

  @typedoc """
  An RFC 5424 Syslog severity level atom (lowercased), matching
  Elixir / Erlang `:logger.level/0` exactly.
  """
  @type syslog_level ::
          :emergency | :alert | :critical | :error | :warning | :notice | :info | :debug

  @doc """
  **Application** (Convenience) — map an RFC 5424 Syslog level
  atom to an OTel `SeverityNumber` per spec Appendix B Syslog row
  (`logs/data-model-appendix.md` L806-L818).

  | Syslog level | SeverityNumber | OTel short name |
  |---|---|---|
  | `:emergency` | 21 | FATAL |
  | `:alert` | 19 | ERROR3 |
  | `:critical` | 18 | ERROR2 |
  | `:error` | 17 | ERROR |
  | `:warning` | 13 | WARN |
  | `:notice` | 10 | INFO2 |
  | `:info` | 9 | INFO |
  | `:debug` | 5 | DEBUG |

  Distinct Syslog levels within the same range (e.g. `:error` vs
  `:critical` in ERROR) are assigned different numbers per spec
  L280-L283, preserving their relative ordering. Elixir `:logger`
  uses these same atom names, so the handler can call this
  directly without any intermediate conversion.
  """
  @spec from_syslog_level(level :: syslog_level()) :: t()
  def from_syslog_level(:emergency), do: 21
  def from_syslog_level(:alert), do: 19
  def from_syslog_level(:critical), do: 18
  def from_syslog_level(:error), do: 17
  def from_syslog_level(:warning), do: 13
  def from_syslog_level(:notice), do: 10
  def from_syslog_level(:info), do: 9
  def from_syslog_level(:debug), do: 5
end
