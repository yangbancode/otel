defmodule Otel.SDK.Logs.LogRecord.Limits do
  @moduledoc """
  Configurable limits for `LogRecord` attribute collections
  (`logs/sdk.md` §LogRecord Limits L321-348).

  Holds the two limit values and exposes two pure-transform
  helpers — `truncate_attributes/2` and `drop_attributes/2`
  — that each enforce one limit independently. Composition
  ordering, dropped-count tracking, and the spec-required
  discard message (`logs/sdk.md` L345-348) are the
  orchestrator's responsibility — see
  `Otel.SDK.Logs.Logger.build_log_record/3`.

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

  ## References

  - OTel Logs SDK §LogRecord Limits: `opentelemetry-specification/specification/logs/sdk.md` L321-348
  - OTel Common §Attribute Limits: `opentelemetry-specification/specification/common/README.md` L249-299
  - OTel Common §Configurable Parameters: `opentelemetry-specification/specification/common/README.md` L303-306
  - Mapping to non-OTLP §Dropped Attributes Count: `opentelemetry-specification/specification/common/mapping-to-non-otlp.md` L73-79
  - Env vars: `opentelemetry-specification/specification/configuration/sdk-environment-variables.md` L181-204
  """

  use Otel.API.Common.Types

  @typedoc """
  Attribute map shape accepted by the helpers.

  Mirrors `Otel.API.Logs.LogRecord.attributes`
  (`apps/otel_api/lib/otel/api/logs/log_record.ex` L74) — the
  public `LogRecord.attributes` field type. Both keys and
  values are constrained to the OTel attribute contract
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
  Truncates each attribute value by the given length limit.

  Strings are sliced by character (grapheme) count;
  `{:bytes, _}` values by byte count; lists recurse element-wise.
  All other primitives pass through unchanged. `:infinity`
  returns the input map as-is.
  """
  @spec truncate_attributes(attributes :: attributes(), limit :: non_neg_integer() | :infinity) ::
          attributes()
  def truncate_attributes(attributes, :infinity), do: attributes

  def truncate_attributes(attributes, limit) do
    Map.new(attributes, fn {key, value} -> {key, truncate_attribute(value, limit)} end)
  end

  @doc """
  Drops attributes beyond the given count limit.

  Returns the input map unchanged when its size is within the
  limit; otherwise returns the first `limit` entries (map
  iteration order — spec is silent on which to keep when over
  the limit).
  """
  @spec drop_attributes(attributes :: attributes(), limit :: non_neg_integer()) :: attributes()
  def drop_attributes(attributes, limit) when map_size(attributes) <= limit, do: attributes

  def drop_attributes(attributes, limit) do
    attributes |> Enum.take(limit) |> Map.new()
  end

  @spec truncate_attribute(value :: primitive() | [primitive()], limit :: non_neg_integer()) ::
          primitive() | [primitive()]
  defp truncate_attribute({:bytes, bin}, limit) when is_binary(bin) and byte_size(bin) > limit do
    {:bytes, binary_part(bin, 0, limit)}
  end

  defp truncate_attribute(value, limit) when is_binary(value) do
    if String.length(value) > limit, do: String.slice(value, 0, limit), else: value
  end

  defp truncate_attribute(value, limit) when is_list(value) do
    Enum.map(value, &truncate_attribute(&1, limit))
  end

  defp truncate_attribute(value, _limit), do: value
end
