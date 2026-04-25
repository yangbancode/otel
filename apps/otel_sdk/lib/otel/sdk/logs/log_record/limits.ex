defmodule Otel.SDK.Logs.LogRecord.Limits do
  @moduledoc """
  Configurable limits for `LogRecord` attribute collections
  (`logs/sdk.md` §LogRecord Limits L321-348).

  Prevents unbounded growth of LogRecord attributes by enforcing
  the common attribute rules from `common/README.md` §Attribute
  Limits (L249-299). Excess attributes are silently discarded;
  string and byte values exceeding the length limit are
  truncated.

  ## Configurable parameters

  | Field | Default | Spec |
  |---|---|---|
  | `attribute_count_limit` | `128` | `common/README.md` L305 — *"Maximum allowed attribute count per record"* |
  | `attribute_value_length_limit` | `:infinity` | `common/README.md` L306 — *"Maximum allowed attribute value length (applies to string values and byte arrays)"* |

  Both fields accept any `t:non_neg_integer/0` (per the
  spec value-range definition in `sdk-environment-variables.md`
  L181-204 *"Valid values are non-negative"*) — `0` is a
  valid setting that drops every attribute or truncates every
  value to empty.

  > #### TODO — env / config wiring deferred {: .info}
  >
  > Spec env vars `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` and
  > `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` are not
  > read in this module. Env / Application config handling
  > was stripped from the SDK during the per-module review
  > phase and will be reintroduced in the finalization pass
  > as a distributed scheme (each module owns its keys with
  > a thin shared helper). Until then, the only configuration
  > paths are the struct defaults and explicit programmatic
  > overrides via `Otel.SDK.Logs.LoggerProvider.start_link/1`.

  ## Truncation rules

  Values pass through type-specific truncation per
  `common/README.md` L260-274. The cases below are the only
  shapes the `LogRecord.attributes` value type permits
  (`apps/otel_api/lib/otel/api/logs/log_record.ex` L74:
  `primitive() | [primitive()]`).

  | Value shape | Truncation |
  |---|---|
  | `String.t()` | character (grapheme) count via `String.slice/3` (spec L262-263 *"counting any character in it as 1"*) |
  | `{:bytes, binary()}` | byte count via `binary_part/3` (spec L265-267 *"counting each byte as 1"*) |
  | `[primitive()]` | element-wise recursion (spec L268-269) |
  | `boolean()`, `integer()`, `float()`, `nil` | passes through unchanged (spec L274 *"otherwise a value MUST NOT be truncated"*) |

  The spec also defines map-valued (`common/README.md`
  L272-273) and AnyValue-array (L270-271) recursion. Neither
  applies here — `LogRecord.attributes`'s
  `primitive() | [primitive()]` value type
  (`apps/otel_api/lib/otel/api/common/types.ex` L180-L181)
  excludes nested maps and heterogeneous AnyValue arrays. The
  `Otel.LoggerHandler` body path
  (`apps/otel_logger_handler/lib/otel/logger_handler.ex`)
  uses `primitive_any()` for that recursion; attribute values
  here are intentionally a flatter subset.

  ## Discard message

  Per `logs/sdk.md` L345-348, when an attribute is discarded
  the SDK SHOULD log a message and MUST emit it at most once
  per LogRecord. The MUST is satisfied structurally — `apply/2`
  is invoked exactly once per LogRecord by
  `Otel.SDK.Logs.Logger`
  (`apps/otel_sdk/lib/otel/sdk/logs/logger.ex` L65-L66) — and
  the trigger is broadened per `common/README.md` L284-286 to
  cover both discard and truncation. The change-detection
  uses a structural equality comparison (`==`) between the
  pre- and post-truncation maps, so any value that survives
  unchanged contributes no signal to the warning.

  ### Self-reference

  The warning is emitted via `Logger.warning/1`, which means
  the SDK's own LogRecord-limit warning re-enters the OTel
  pipeline whenever `Otel.LoggerHandler` is installed. The
  re-entered record carries a single short-string attribute
  payload, well below the default limits, so it produces no
  additional warning — the recursion is bounded at depth 1.

  This matches `opentelemetry-erlang`'s pattern:
  `otel_log_handler.erl` L233 emits `?LOG_WARNING(...)` on
  exporter failure, and `otel_exporter.erl` /
  `otel_configuration.erl` use `?LOG_WARNING` / `?LOG_INFO`
  throughout — none set a domain or filter to skip the OTel
  bridge, so SDK self-warnings are part of the user
  telemetry stream by design.

  ## References

  - OTel Logs SDK §LogRecord Limits: `opentelemetry-specification/specification/logs/sdk.md` L321-348
  - OTel Common §Attribute Limits: `opentelemetry-specification/specification/common/README.md` L249-299
  - OTel Common §Configurable Parameters: `opentelemetry-specification/specification/common/README.md` L303-306
  - Mapping to non-OTLP §Dropped Attributes Count: `opentelemetry-specification/specification/common/mapping-to-non-otlp.md` L73-79
  - Env vars: `opentelemetry-specification/specification/configuration/sdk-environment-variables.md` L181-204
  """

  require Logger

  use Otel.API.Common.Types

  @typedoc """
  Attribute map shape accepted by `apply/2`.

  Mirrors `Otel.API.Logs.LogRecord.attributes` (`apps/otel_api/lib/otel/api/logs/log_record.ex` L74)
  — the public `LogRecord.attributes` field type. Both keys
  and values are constrained to the OTel attribute contract
  (`common/README.md` §Attribute L185-L197).
  """
  @type attributes :: %{String.t() => primitive() | [primitive()]}

  @type t :: %__MODULE__{
          attribute_count_limit: non_neg_integer(),
          attribute_value_length_limit: non_neg_integer() | :infinity
        }

  defstruct attribute_count_limit: 128,
            attribute_value_length_limit: :infinity

  @doc """
  Applies attribute limits to a map of attributes.

  Truncates string values exceeding the length limit and silently
  discards attributes beyond the count limit.
  """
  @spec apply(attributes :: attributes(), limits :: t()) ::
          {attributes(), non_neg_integer()}
  def apply(attributes, %__MODULE__{} = limits) do
    truncated = truncate_values(attributes, limits.attribute_value_length_limit)
    {limited, dropped} = drop_excess(truncated, limits.attribute_count_limit)
    log_limits_applied(dropped, truncated != attributes)
    {limited, dropped}
  end

  @spec truncate_values(attributes :: attributes(), limit :: non_neg_integer() | :infinity) ::
          attributes()
  defp truncate_values(attributes, :infinity), do: attributes

  defp truncate_values(attributes, limit) do
    Map.new(attributes, fn {key, value} -> {key, truncate_value(value, limit)} end)
  end

  @spec truncate_value(value :: primitive() | [primitive()], limit :: non_neg_integer()) ::
          primitive() | [primitive()]
  defp truncate_value({:bytes, bin}, limit) when is_binary(bin) and byte_size(bin) > limit do
    {:bytes, binary_part(bin, 0, limit)}
  end

  defp truncate_value(value, limit) when is_binary(value) do
    if String.length(value) > limit, do: String.slice(value, 0, limit), else: value
  end

  defp truncate_value(value, limit) when is_list(value) do
    Enum.map(value, &truncate_value(&1, limit))
  end

  defp truncate_value(value, _limit), do: value

  @spec drop_excess(attributes :: attributes(), limit :: non_neg_integer()) ::
          {attributes(), non_neg_integer()}
  defp drop_excess(attributes, limit) do
    count = map_size(attributes)

    if count > limit do
      kept = attributes |> Enum.take(limit) |> Map.new()
      {kept, count - limit}
    else
      {attributes, 0}
    end
  end

  @spec log_limits_applied(dropped :: non_neg_integer(), truncated? :: boolean()) :: :ok
  defp log_limits_applied(0, false), do: :ok

  defp log_limits_applied(dropped, truncated?) do
    parts =
      [
        dropped > 0 && "dropped #{dropped} attribute(s)",
        truncated? && "truncated value(s) exceeding length limit"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    Logger.warning("LogRecord limits applied: #{parts}")
    :ok
  end
end
