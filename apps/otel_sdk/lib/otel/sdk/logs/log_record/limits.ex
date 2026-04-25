defmodule Otel.SDK.Logs.LogRecord.Limits do
  @moduledoc """
  Configurable limits for `Otel.API.Logs.LogRecord` attribute
  collections (`logs/sdk.md` §LogRecord Limits L321-348).

  Holds the two limit values and exposes a single `apply/2`
  entry point that returns a new `LogRecord` with both
  limits enforced. Composition ordering, dropped-count
  tracking, and the spec-required discard message
  (`logs/sdk.md` L345-348) are the orchestrator's
  responsibility — see `Otel.SDK.Logs.Logger.build_log_record/3`.

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

  ## Naming convention

  Private functions follow an `apply_<field-name>` rule —
  each `apply_*_limit/2` enforces one specific limit field on
  the struct (`attribute_` prefix dropped, since the
  surrounding namespace already implies attribute scope). The
  per-element helper `truncate_value/2` is a recursive utility
  used by `apply_value_length_limit/2`; it does not enforce a
  limit on its own and so falls outside the `apply_*` family.

  ## References

  - OTel Logs SDK §LogRecord Limits: `opentelemetry-specification/specification/logs/sdk.md` L321-348
  - OTel Common §Attribute Limits: `opentelemetry-specification/specification/common/README.md` L249-299
  - OTel Common §Configurable Parameters: `opentelemetry-specification/specification/common/README.md` L303-306
  - Mapping to non-OTLP §Dropped Attributes Count: `opentelemetry-specification/specification/common/mapping-to-non-otlp.md` L73-79
  - Env vars: `opentelemetry-specification/specification/configuration/sdk-environment-variables.md` L181-204
  """

  @type t :: %__MODULE__{
          attribute_count_limit: non_neg_integer(),
          attribute_value_length_limit: non_neg_integer() | :infinity
        }

  defstruct attribute_count_limit: 128,
            attribute_value_length_limit: :infinity

  @doc """
  Applies all attribute limits to a `LogRecord`.

  Truncation precedes count-drop so `dropped_attributes_count`
  (computed by the caller as a `map_size` delta) reflects only
  count-limit drops. Pattern-matches the record's `attributes`
  field so the private pipeline operates on a pure map and the
  struct is rewrapped only once.
  """
  @spec apply(log_record :: Otel.API.Logs.LogRecord.t(), limits :: t()) ::
          Otel.API.Logs.LogRecord.t()
  def apply(
        %Otel.API.Logs.LogRecord{attributes: attributes} = log_record,
        %__MODULE__{
          attribute_value_length_limit: value_length_limit,
          attribute_count_limit: count_limit
        }
      ) do
    new_attributes =
      attributes
      |> apply_value_length_limit(value_length_limit)
      |> apply_count_limit(count_limit)

    %{log_record | attributes: new_attributes}
  end

  @spec apply_value_length_limit(attributes :: map(), limit :: non_neg_integer() | :infinity) ::
          map()
  defp apply_value_length_limit(attributes, :infinity), do: attributes

  defp apply_value_length_limit(attributes, limit) do
    Map.new(attributes, fn {key, value} -> {key, truncate_value(value, limit)} end)
  end

  @spec apply_count_limit(attributes :: map(), limit :: non_neg_integer()) :: map()
  defp apply_count_limit(attributes, limit) when map_size(attributes) <= limit, do: attributes

  defp apply_count_limit(attributes, limit) do
    attributes |> Enum.take(limit) |> Map.new()
  end

  @spec truncate_value(value :: term(), limit :: non_neg_integer()) :: term()
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
end
