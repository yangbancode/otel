defmodule Otel.Logs.LogRecordLimits do
  @moduledoc """
  Configurable limits for `Otel.Logs.LogRecord` attribute
  collections (`logs/sdk.md` §LogRecord Limits L321-348).

  Holds the two limit values and exposes a single `apply/2`
  entry point that returns the limited `LogRecord` together
  with the dropped-attributes count for the orchestrator to
  forward into `Otel.Logs.LogRecord.dropped_attributes_count`.
  Composition ordering and the spec-required discard message
  (`logs/sdk.md` L345-348) remain the orchestrator's
  responsibility — see `Otel.Logs.Logger.emit/2`.

  ## Configurable parameters

  | Field | Default | Spec |
  |---|---|---|
  | `attribute_count_limit` | `128` | `common/README.md` L305 — *"Maximum allowed attribute count per record"* |
  | `attribute_value_length_limit` | `:infinity` | `common/README.md` L306 — *"Maximum allowed attribute value length (applies to string values and byte arrays)"* |

  Both fields accept any `t:non_neg_integer/0` (per the
  spec value-range definition in `sdk-environment-variables.md`
  L197-L204 *"Valid values are non-negative"*) — `0` is a
  valid setting that drops every attribute or truncates every
  value to empty.

  ## Configuration sources

  Spec env vars `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` and
  `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` are not read.
  Minikube hardcodes the spec defaults; `Otel.Logs.Logger`
  carries the limits as a compile-time literal
  (`@log_record_limits`) and there is no runtime override.

  ## Truncation rules

  `LogRecord.attributes` values are the full
  `t:primitive_any/0` per spec
  (`opentelemetry-proto/opentelemetry/proto/logs/v1/logs.proto`
  L178 — `repeated KeyValue` where `KeyValue.value = AnyValue`).
  Truncation applies recursively per `common/README.md`
  L260-L274:

  | Value shape | Truncation |
  |---|---|
  | `String.t()` | character (grapheme) count via `String.slice/3` (spec L262-263 *"counting any character in it as 1"*) |
  | `{:bytes, binary()}` | byte count via `binary_part/3` (spec L265-267 *"counting each byte as 1"*) |
  | `[primitive_any()]` | element-wise recursion — covers both homogeneous primitive arrays (spec L268-269) and heterogeneous AnyValue arrays (spec L270-271) |
  | `%{String.t() => primitive_any()}` | recursion over map values (spec L272-273) |
  | `boolean()`, `integer()`, `float()`, `nil` | passes through unchanged (spec L274 *"otherwise a value MUST NOT be truncated"*) |

  ## References

  - OTel Logs SDK §LogRecord Limits: `opentelemetry-specification/specification/logs/sdk.md` L321-348
  - OTel Common §Attribute Limits: `opentelemetry-specification/specification/common/README.md` L249-299
  - OTel Common §Configurable Parameters: `opentelemetry-specification/specification/common/README.md` L303-306
  - Mapping to non-OTLP §Dropped Attributes Count: `opentelemetry-specification/specification/common/mapping-to-non-otlp.md` L73-79
  - Env vars: `opentelemetry-specification/specification/configuration/sdk-environment-variables.md` L197-L204
  """

  use Otel.Common.Types

  @default_attribute_count_limit 128
  @default_attribute_value_length_limit :infinity

  @type t :: %__MODULE__{
          attribute_count_limit: non_neg_integer(),
          attribute_value_length_limit: non_neg_integer() | :infinity
        }

  defstruct [:attribute_count_limit, :attribute_value_length_limit]

  @doc """
  **SDK** — Construct log-record limits. Defaults match
  `logs/sdk.md` §LogRecord Limits.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    defaults = %{
      attribute_count_limit: @default_attribute_count_limit,
      attribute_value_length_limit: @default_attribute_value_length_limit
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end

  @doc """
  Applies all attribute limits to a `LogRecord`.

  Returns `{limited_record, dropped_attributes_count}`. The
  count is the size delta from the count-limit drop step
  (truncation precedes drop and preserves map size, so the
  delta is exclusively the dropped-attribute count that
  belongs in `Otel.Logs.LogRecord.dropped_attributes_count`
  and the OTLP proto field of the same name).
  """
  @spec apply(log_record :: Otel.Logs.LogRecord.t(), limits :: t()) ::
          {Otel.Logs.LogRecord.t(), non_neg_integer()}
  def apply(
        %Otel.Logs.LogRecord{attributes: attributes} = log_record,
        %__MODULE__{
          attribute_value_length_limit: value_length_limit,
          attribute_count_limit: count_limit
        }
      ) do
    new_attributes = attributes |> truncate(value_length_limit) |> drop(count_limit)

    {
      %{log_record | attributes: new_attributes},
      map_size(attributes) - map_size(new_attributes)
    }
  end

  @spec drop(
          attributes :: %{String.t() => primitive_any()},
          limit :: non_neg_integer()
        ) :: %{String.t() => primitive_any()}
  defp drop(attributes, limit) when map_size(attributes) <= limit, do: attributes

  defp drop(attributes, limit) do
    attributes |> Enum.take(limit) |> Map.new()
  end

  # Recursive truncation walker. Handles the top-level
  # `attributes` map (called from `apply/2`) and every nested
  # value uniformly via the `is_map` clause — `do_truncate/2`
  # used to be a separate function for that, but the map walk
  # is identical so a single function covers both.
  @spec truncate(value :: primitive_any(), limit :: non_neg_integer() | :infinity) ::
          primitive_any()
  defp truncate(value, :infinity), do: value

  defp truncate({:bytes, bin}, limit) when is_binary(bin) and byte_size(bin) > limit do
    {:bytes, binary_part(bin, 0, limit)}
  end

  defp truncate(value, limit) when is_binary(value) do
    if String.length(value) > limit, do: String.slice(value, 0, limit), else: value
  end

  defp truncate(value, limit) when is_list(value) do
    Enum.map(value, &truncate(&1, limit))
  end

  defp truncate(value, limit) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, truncate(v, limit)} end)
  end

  defp truncate(value, _limit), do: value
end
