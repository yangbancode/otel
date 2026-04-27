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

  ## Schema source — build-time compilation

  The schema is bundled at
  `priv/schemas/v1.0.0/opentelemetry_configuration.json`,
  compiled by `JSONSchex` **at this module's compile time**, and
  the result is `:erlang.term_to_binary/1`-serialized into the
  `@schema_binary` module attribute. `validate!/1` decodes the
  binary on each call.

  No runtime caching — every call decodes the binary literal
  fresh. Per-call cost ~2ms (binary_to_term on ~800 KB) vs
  ~8ms for a full re-parse + re-compile, while keeping the
  function pure (deterministic, no shared state, no race risk).

  `JSONSchex`'s compiled schema contains anonymous-function
  closures, so it cannot be embedded directly as a module
  attribute literal (`Macro.escape/1` and `unquote/1` reject
  function literals). Going through `term_to_binary/1` works
  because binaries *are* valid attribute literals, and
  `binary_to_term/1` reconstitutes the closures from the
  embedded module references.

  `@external_resource` registers the schema file so the module
  recompiles automatically when it changes.

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

  # Resolved relative to this source file (rather than via
  # `:code.priv_dir/1`) so the path is valid during the
  # compile-time `@external_resource` + `File.read!/1`
  # expansion, before the app's priv dir exists in `_build`.
  @schema_path Path.expand(
                 "../../../priv/schemas/v1.0.0/opentelemetry_configuration.json",
                 __DIR__
               )

  @external_resource @schema_path

  # Compile + serialize at this module's compile time. The
  # resulting binary is embedded as a module attribute literal
  # in the BEAM file. Closures inside the compiled schema
  # survive `term_to_binary`/`binary_to_term` round-trip
  # because the runtime restores them by module reference.
  {:ok, compiled_at_build} =
    @schema_path
    |> File.read!()
    |> Jason.decode!()
    |> JSONSchex.compile()

  @schema_binary :erlang.term_to_binary(compiled_at_build)

  @doc """
  Validates `model` against the bundled v1.0.0 schema.

  Returns `:ok` on success. Raises `ArgumentError` with a formatted
  list of validation errors (path + rule) on failure.
  """
  @spec validate!(model :: map()) :: :ok
  def validate!(model) when is_map(model) do
    case JSONSchex.validate(:erlang.binary_to_term(@schema_binary), model) do
      :ok -> :ok
      {:error, errors} -> raise ArgumentError, format_errors(errors)
    end
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
