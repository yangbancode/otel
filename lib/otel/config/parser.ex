defmodule Otel.Config.Parser do
  @moduledoc """
  YAML → in-memory term parser for declarative configuration files
  (`OTEL_CONFIG_FILE`).

  Implements the **first half** of spec
  `configuration/sdk.md` §Parse — read the file, parse YAML into
  an Elixir term. The remaining Parse responsibilities (env-var
  substitution + JSON-Schema validation against the
  `opentelemetry-configuration` v1.0.0 schema) land in their own
  modules and compose at the `Otel.Config` entry point in later
  PRs.

  The output of this module is intentionally raw — values are
  whatever the YAML produced (strings, numbers, booleans, `nil`,
  lists, maps with string keys). No type coercion or normalization.

  ## Spec contract observed by the underlying parser

  - **null vs missing distinction** (`configuration/sdk.md`
    L209-L221, MUST). YAML's `key:` and `key: null` both produce
    `%{"key" => nil}` (key *present*, value `nil`). Absent keys
    do not appear in the map. `Map.has_key?/2` discriminates the
    two cases — required by spec.
  - **File not found / unreadable** raises
    `YamlElixir.FileNotFoundError`; **YAML syntax errors** raise
    `YamlElixir.ParsingError`. The wiring layer
    (`Otel.SDK.Application`) decides whether to propagate or
    fall back; this module follows the project's happy-path
    convention and lets the failures surface.

  ## Public API

  | Function | Role |
  |---|---|
  | `parse_file!/1` | **SDK** (file entry point) — read + parse a YAML file |
  | `parse_string!/1` | **SDK** (in-memory entry point) — parse a YAML string |

  ## References

  - Spec Parse: `opentelemetry-specification/specification/configuration/sdk.md` §Parse
  - YAML format: `opentelemetry-specification/specification/configuration/data-model.md` §YAML file format
  """

  @doc """
  Reads `path` and parses its contents as YAML.

  Raises `YamlElixir.FileNotFoundError` if the file cannot be
  read, `YamlElixir.ParsingError` if the YAML is malformed.
  """
  @spec parse_file!(path :: Path.t()) :: term()
  def parse_file!(path) when is_binary(path) do
    YamlElixir.read_from_file!(path)
  end

  @doc """
  Parses a YAML string into an Elixir term.

  Raises `YamlElixir.ParsingError` if the YAML is malformed.
  """
  @spec parse_string!(yaml :: binary()) :: term()
  def parse_string!(yaml) when is_binary(yaml) do
    YamlElixir.read_from_string!(yaml)
  end
end
