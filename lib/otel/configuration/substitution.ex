defmodule Otel.Configuration.Substitution do
  @moduledoc """
  Environment variable substitution for declarative configuration
  files (`OTEL_CONFIG_FILE`).

  Implements spec
  `configuration/data-model.md` §Environment variable substitution
  (Status: Stable as of v1.55.0). Operates at the **raw text
  level** — substitution runs before YAML parsing so that the
  YAML parser interprets node types (boolean, integer, etc.) on
  the *substituted* values, satisfying spec MUST: *"Node types
  MUST be interpreted after environment variable substitution
  takes place."*

  Pipeline used by `Otel.Configuration`:

      File.read!(path)
      |> Otel.Configuration.Substitution.substitute!()
      |> Otel.Configuration.Parser.parse_string!()

  ## Supported syntax

  | Pattern | Resolves to |
  |---|---|
  | `${VAR}` | env var `VAR`, or empty string if unset |
  | `${env:VAR}` | same as `${VAR}` (explicit `env` prefix) |
  | `${VAR:-default}` | env var `VAR`, or `default` if unset / empty |
  | `${env:VAR:-default}` | same as above with explicit prefix |
  | `$$` | literal `$` (escape) |

  ## Errors

  - **Unsupported prefix** (anything other than absent or `env`,
    e.g. `${sys:foo}`) raises `ArgumentError`. Spec L362-L367
    permits language-specific prefixes (`MAY`); we only honor
    `env` for now.
  - **Invalid `ENV-NAME`** (must match `[a-zA-Z_][a-zA-Z0-9_]*`,
    e.g. `${1FOO}` or `${API_$KEY}`) raises `ArgumentError`. Spec
    `data-model.md` L378-L382 mandates *"the parser must return
    an empty result (no partial results are allowed) and an error
    describing the parse failure"*.
  - **Unterminated `${`** raises `ArgumentError`.

  ## Public API

  | Function | Role |
  |---|---|
  | `substitute!/1` | **SDK** (Parse helper) — apply env-var substitution to raw text |

  ## References

  - Spec: `opentelemetry-specification/specification/configuration/data-model.md` §Environment variable substitution
  """

  # Per spec ENV-NAME grammar (data-model.md). Compiled at module
  # load to keep the substitution hot path allocation-free.
  @env_name_regex ~r/\A[a-zA-Z_][a-zA-Z0-9_]*\z/

  # Splits a `${...}` body into `{prefix, content}`. Negative
  # lookahead `(?!-)` distinguishes a prefix delimiter (`env:VAR`)
  # from the `:-` start of an ENV-SUBSTITUTION default
  # (`VAR:-default`). The `s` modifier lets `.` match newlines —
  # DEFAULT-VALUE may legitimately contain whitespace.
  @prefix_regex ~r/\A([a-zA-Z][a-zA-Z0-9_]*):(?!-)(.*)/s

  @doc """
  Applies env-var substitution to `raw` per spec
  `configuration/data-model.md` §Environment variable substitution.

  Raises `ArgumentError` on any malformed substitution reference.
  """
  @spec substitute!(raw :: binary()) :: binary()
  def substitute!(raw) when is_binary(raw) do
    raw
    |> scan([])
    |> IO.iodata_to_binary()
  end

  # Walk left-to-right, identifying `$$` escapes and `${...}`
  # references; literal chars pass through. Mirrors the spec's
  # pseudocode at data-model.md L348-L376.

  @spec scan(input :: binary(), acc :: iodata()) :: iodata()
  defp scan(<<"$$", rest::binary>>, acc), do: scan(rest, [acc, "$"])

  defp scan(<<"${", rest::binary>>, acc) do
    case String.split(rest, "}", parts: 2) do
      [body, after_close] ->
        scan(after_close, [acc, resolve!(body)])

      [_unterminated] ->
        raise ArgumentError,
              "unterminated substitution reference: ${#{rest}"
    end
  end

  defp scan(<<c::utf8, rest::binary>>, acc), do: scan(rest, [acc, <<c::utf8>>])
  defp scan(<<>>, acc), do: acc

  # Resolve the body of one `${...}`. Strips the optional `env:`
  # prefix, validates ENV-NAME, applies optional `:-DEFAULT`.

  @spec resolve!(body :: binary()) :: binary()
  defp resolve!(body) do
    case Regex.run(@prefix_regex, body) do
      [_full, "env", env_body] -> resolve_env!(env_body)
      [_full, prefix, _] -> raise_unsupported_prefix!(prefix)
      nil -> resolve_env!(body)
    end
  end

  @spec resolve_env!(env_body :: binary()) :: binary()
  defp resolve_env!(env_body) do
    {name, default} =
      case String.split(env_body, ":-", parts: 2) do
        [name] -> {name, nil}
        [name, default] -> {name, default}
      end

    validate_env_name!(name)

    case {System.get_env(name), default} do
      # Spec L347-L350: env var defined and non-empty wins.
      {value, _} when is_binary(value) and value != "" -> value
      # Empty or undefined: fall back to default if provided,
      # else empty string.
      {_, default} when is_binary(default) -> default
      {_, nil} -> ""
    end
  end

  @spec validate_env_name!(name :: binary()) :: :ok
  defp validate_env_name!(name) do
    if Regex.match?(@env_name_regex, name) do
      :ok
    else
      raise ArgumentError,
            "invalid ENV-NAME #{inspect(name)} — must match [a-zA-Z_][a-zA-Z0-9_]*"
    end
  end

  @spec raise_unsupported_prefix!(prefix :: binary()) :: no_return()
  defp raise_unsupported_prefix!(prefix) do
    raise ArgumentError,
          "unsupported substitution prefix #{inspect(prefix)} — only `env` (or absent) is supported"
  end
end
