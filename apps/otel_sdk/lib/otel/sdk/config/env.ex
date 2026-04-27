defmodule Otel.SDK.Config.Env do
  @moduledoc """
  Spec-compliant typed reads of `OTEL_*` environment variables.

  Implements the value-parsing semantics from
  `configuration/sdk-environment-variables.md` L48-L107 (parse rules)
  and `configuration/common.md` L77-L102 (Duration / Timeout).

  All readers return `nil` when the variable is unset *or* when its
  value fails to parse — and emit a `Logger.warning` per the spec
  guidance attached to each parse rule. Callers treat `nil` as
  *"fall through to the next layer"* (Application env → built-in
  default), giving a clean three-layer composition.

  ## Public API

  | Function | Spec rule |
  |---|---|
  | `string/1` | L60 — empty value MUST be treated as unset |
  | `boolean/1` | L66-L76 — only case-insensitive `"true"` is true |
  | `integer/1` | L88-L90 — SHOULD warn + treat as unset on unparseable |
  | `duration_ms/1` | `common.md` L77-L82 — non-negative milliseconds |
  | `timeout_ms/1` | `common.md` L92-L102 — `0` SHOULD mean infinite |
  | `enum/2` | L103-L107 — case-insensitive; unknown MUST warn + ignore |
  | `list/1` | comma-separated; empty entries dropped |

  ## References

  - OTel SDK env vars: `opentelemetry-specification/specification/configuration/sdk-environment-variables.md`
  - OTel SDK common: `opentelemetry-specification/specification/configuration/common.md`
  """

  require Logger

  @doc """
  Reads `var` as a string. Spec L60 — empty value MUST be unset.
  """
  @spec string(var :: String.t()) :: String.t() | nil
  def string(var) do
    case System.get_env(var) do
      nil -> nil
      "" -> nil
      value -> value
    end
  end

  @doc """
  Reads `var` as a boolean. Spec L66-L76 — only case-insensitive
  `"true"` is true; everything else is `false`. Unparseable values
  fall to `false` with a warning.
  """
  @spec boolean(var :: String.t()) :: boolean() | nil
  def boolean(var) do
    case string(var) do
      nil ->
        nil

      raw ->
        case String.downcase(raw) do
          "true" ->
            true

          "false" ->
            false

          _ ->
            Logger.warning(
              "Otel.SDK.Config.Env: #{var}=#{inspect(raw)} is not a valid boolean " <>
                "(spec accepts only \"true\" / \"false\"); treating as false."
            )

            false
        end
    end
  end

  @doc """
  Reads `var` as an integer. Spec L88-L90 — unparseable values SHOULD
  warn and be treated as unset.
  """
  @spec integer(var :: String.t()) :: integer() | nil
  def integer(var) do
    case string(var) do
      nil ->
        nil

      raw ->
        case Integer.parse(raw) do
          {n, ""} ->
            n

          _ ->
            Logger.warning(
              "Otel.SDK.Config.Env: #{var}=#{inspect(raw)} is not a valid integer; " <>
                "treating as unset."
            )

            nil
        end
    end
  end

  @doc """
  Reads `var` as a Duration in milliseconds. `common.md` L77-L82 —
  non-negative milliseconds. Negative values warn and are ignored.
  """
  @spec duration_ms(var :: String.t()) :: non_neg_integer() | nil
  def duration_ms(var) do
    case integer(var) do
      nil ->
        nil

      n when n >= 0 ->
        n

      n ->
        Logger.warning(
          "Otel.SDK.Config.Env: #{var}=#{n} is negative; treating as unset " <>
            "(Duration MUST be non-negative)."
        )

        nil
    end
  end

  @doc """
  Reads `var` as a Timeout in milliseconds. `common.md` L92-L102 —
  `0` SHOULD mean *no limit* (returned as `:infinity`).
  """
  @spec timeout_ms(var :: String.t()) :: non_neg_integer() | :infinity | nil
  def timeout_ms(var) do
    case duration_ms(var) do
      nil -> nil
      0 -> :infinity
      n -> n
    end
  end

  @doc """
  Reads `var` as an enum, matching its lowercased value against the
  `allowed` atoms (compared by their `Atom.to_string/1` form). Spec
  L103-L107 — unknown values MUST warn and be ignored.
  """
  @spec enum(var :: String.t(), allowed :: [atom()]) :: atom() | nil
  def enum(var, allowed) do
    case string(var) do
      nil -> nil
      raw -> match_enum(var, raw, allowed)
    end
  end

  @spec match_enum(var :: String.t(), raw :: String.t(), allowed :: [atom()]) :: atom() | nil
  defp match_enum(var, raw, allowed) do
    target = String.downcase(raw)

    case Enum.find(allowed, fn atom -> Atom.to_string(atom) == target end) do
      nil ->
        Logger.warning(
          "Otel.SDK.Config.Env: #{var}=#{inspect(raw)} is not one of " <>
            "#{inspect(allowed)}; treating as unset."
        )

        nil

      atom ->
        atom
    end
  end

  @doc """
  Reads `var` as a comma-separated list of trimmed, non-empty
  strings. Returns `nil` when the variable is unset.

  Note: spec L118 mandates dedup only for `OTEL_PROPAGATORS`; this
  helper does not dedup — call sites that need it must do so.
  """
  @spec list(var :: String.t()) :: [String.t()] | nil
  def list(var) do
    case string(var) do
      nil ->
        nil

      raw ->
        raw
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end
end
