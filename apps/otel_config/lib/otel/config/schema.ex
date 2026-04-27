defmodule Otel.Config.Schema do
  @moduledoc """
  JSON Schema validation of post-substitution declarative
  configuration models against the
  [opentelemetry-configuration v1.0.0 schema](https://github.com/open-telemetry/opentelemetry-configuration/blob/v1.0.0/opentelemetry_configuration.json).

  Implements the schema-validation half of spec
  `configuration/sdk.md` §Parse:
  *"Parse SHOULD return an error if [...] the parsed file content
  does not conform to the configuration model schema."*

  Pipeline used by `Otel.Config`:

      File.read!(path)
      |> Otel.Config.Substitution.substitute!()
      |> Otel.Config.Parser.parse_string!()
      |> Otel.Config.Schema.validate!()

  Substitution MUST run first — the schema expects native types
  (boolean, integer, etc.) that only become available after
  `${VAR:-default}` is resolved and the YAML parser re-interprets
  the substituted text.

  ## Schema source

  The schema is bundled at
  `priv/schemas/v1.0.0/opentelemetry_configuration.json` and
  loaded + compiled on every `validate!/1` call. Vendored to
  keep validation working without CI / production submodule
  fetches; sync process documented alongside the file.

  **No caching** by project policy. `JSONSchex` builds the
  compiled schema as a tree containing anonymous-function
  validators (closures), so it cannot be embedded as a
  compile-time module attribute or pre-serialized to disk via
  `:erlang.term_to_binary/1`. In practice this is fine —
  `Otel.Config.load!/0` is called once at SDK boot, so the cost
  is paid once per VM lifetime regardless.

  v1.0.0 is the **first stable** schema release per its
  [versioning policy](https://github.com/open-telemetry/opentelemetry-configuration/blob/v1.0.0/VERSIONING.md);
  minor versions add only backwards-compatible properties.

  ## Library

  Uses [`jsonschex`](https://hex.pm/packages/jsonschex) — the only
  Elixir JSON Schema validator that supports Draft 2020-12 (the
  draft the OTel schema declares via its `$schema` field). Other
  Elixir validators are pinned to Draft 4/6/7 and would need a
  schema rewrite to work.

  ## `*/development` properties

  The schema accepts `*/development`-suffixed properties as valid
  per the
  [opentelemetry-configuration versioning policy](https://github.com/open-telemetry/opentelemetry-configuration/blob/v1.0.0/VERSIONING.md#applicability)
  — they are explicitly **outside** the stability guarantees but
  still part of the schema. This module *does not* warn about
  them; the Stable-only filtering policy is the
  `Otel.Config.Composer`'s responsibility (separate PR), since
  composition is where mapping to SDK components happens and
  development-only types either resolve to a built-in or are
  rejected at that layer.

  ## Public API

  | Function | Role |
  |---|---|
  | `validate!/1` | **SDK** (Parse helper) — validate parsed model, raise on schema error |

  ## References

  - Schema: `apps/otel_config/priv/schemas/v1.0.0/opentelemetry_configuration.json`
  - Spec Parse: `opentelemetry-specification/specification/configuration/sdk.md` §Parse
  """

  @schema_relative_path "schemas/v1.0.0/opentelemetry_configuration.json"

  @doc """
  Validates `model` against the bundled v1.0.0 schema.

  Returns `:ok` on success. Raises `ArgumentError` with a formatted
  list of validation errors (path + rule) on failure.
  """
  @spec validate!(model :: map()) :: :ok
  def validate!(model) when is_map(model) do
    case JSONSchex.validate(compiled_schema(), model) do
      :ok -> :ok
      {:error, errors} -> raise ArgumentError, format_errors(errors)
    end
  end

  @spec compiled_schema() :: term()
  defp compiled_schema do
    schema =
      :otel_config
      |> :code.priv_dir()
      |> Path.join(@schema_relative_path)
      |> File.read!()
      |> Jason.decode!()

    {:ok, compiled} = JSONSchex.compile(schema)
    compiled
  end

  # Formats the list of jsonschex error structs into a readable
  # multi-line message. Truncates very long error lists so the
  # message stays scannable in CI logs and stack traces.
  @max_errors_shown 10

  @spec format_errors(errors :: [struct()]) :: String.t()
  defp format_errors(errors) do
    shown = Enum.take(errors, @max_errors_shown)
    extra = length(errors) - length(shown)

    lines =
      Enum.map(shown, fn %{path: path, rule: rule} ->
        "  - #{format_path(path)}: #{rule}"
      end)

    suffix =
      if extra > 0,
        do: ["  ... (#{extra} more)"],
        else: []

    Enum.join(
      [
        "configuration file does not conform to opentelemetry-configuration v1.0.0 schema:"
        | lines ++ suffix
      ],
      "\n"
    )
  end

  # jsonschex returns the path with the leaf segment first; reverse
  # it for human reading (root → leaf).
  @spec format_path(path :: [String.t() | non_neg_integer()]) :: String.t()
  defp format_path([]), do: "(root)"

  defp format_path(path) do
    path
    |> Enum.reverse()
    |> Enum.map_join(".", &to_string/1)
  end
end
