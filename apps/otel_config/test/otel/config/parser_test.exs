defmodule Otel.Config.ParserTest do
  use ExUnit.Case, async: true

  @examples_dir Path.expand(
                  "../../../../../references/opentelemetry-configuration/examples",
                  __DIR__
                )

  describe "parse_string!/1" do
    test "returns a map for top-level mappings" do
      yaml = """
      file_format: "1.0"
      """

      assert Otel.Config.Parser.parse_string!(yaml) == %{"file_format" => "1.0"}
    end

    test "preserves null vs missing distinction (spec sdk.md L209-L221 MUST)" do
      yaml = """
      explicit_null: null
      implicit_null:
      with_value: hello
      """

      parsed = Otel.Config.Parser.parse_string!(yaml)

      # All three forms behave per spec:
      assert Map.has_key?(parsed, "explicit_null")
      assert Map.has_key?(parsed, "implicit_null")
      assert Map.has_key?(parsed, "with_value")
      refute Map.has_key?(parsed, "absent_key")

      assert parsed["explicit_null"] == nil
      assert parsed["implicit_null"] == nil
      assert parsed["with_value"] == "hello"
    end

    test "preserves nested structure with mixed types" do
      yaml = """
      tracer_provider:
        sampler:
          parent_based:
            root:
              always_on:
        processors:
          - batch:
              schedule_delay: 5000
              max_queue_size: 2048
      """

      parsed = Otel.Config.Parser.parse_string!(yaml)

      assert get_in(parsed, ["tracer_provider", "sampler", "parent_based", "root"]) == %{
               "always_on" => nil
             }

      assert [%{"batch" => batch}] = parsed["tracer_provider"]["processors"]
      assert batch["schedule_delay"] == 5000
      assert batch["max_queue_size"] == 2048
    end

    test "leaves env var substitution syntax as raw strings (handled in a later layer)" do
      yaml = """
      resource:
        attributes_list: ${OTEL_RESOURCE_ATTRIBUTES}
        nested: ${MY_VAR:-default}
      """

      parsed = Otel.Config.Parser.parse_string!(yaml)

      # Substitution is the env-var-substitution layer's responsibility
      # (separate PR). Parser MUST keep the raw text.
      assert parsed["resource"]["attributes_list"] == "${OTEL_RESOURCE_ATTRIBUTES}"
      assert parsed["resource"]["nested"] == "${MY_VAR:-default}"
    end

    test "raises YamlElixir.ParsingError on malformed YAML" do
      # Mismatched indentation is a structural error, not a YAML
      # tokenization issue — the parser raises a structured error.
      malformed = ":\n  - bad\n bad"

      assert_raise YamlElixir.ParsingError, fn ->
        Otel.Config.Parser.parse_string!(malformed)
      end
    end
  end

  describe "parse_file!/1 with reference example fixtures" do
    # The opentelemetry-configuration submodule (pinned to v1.0.0)
    # ships canonical examples. Treat them as integration tests for
    # the parser layer — any v1.0.0 example MUST parse without
    # raising.

    test "parses examples/otel-getting-started.yaml" do
      parsed = parse_example("otel-getting-started.yaml")

      assert parsed["file_format"] == "1.0"
      assert is_map(parsed["tracer_provider"])
      assert is_map(parsed["meter_provider"])
      assert is_map(parsed["logger_provider"])
    end

    test "parses examples/otel-sdk-config.yaml (the comprehensive example)" do
      parsed = parse_example("otel-sdk-config.yaml")
      assert parsed["file_format"] == "1.0"
    end

    test "parses examples/otel-sdk-migration-config.yaml" do
      parsed = parse_example("otel-sdk-migration-config.yaml")
      assert parsed["file_format"] == "1.0"
    end
  end

  describe "parse_file!/1 error paths" do
    test "raises YamlElixir.FileNotFoundError when the path does not exist" do
      assert_raise YamlElixir.FileNotFoundError, fn ->
        Otel.Config.Parser.parse_file!("/nonexistent/otel-config.yaml")
      end
    end
  end

  @spec parse_example(filename :: String.t()) :: term()
  defp parse_example(filename) do
    @examples_dir |> Path.join(filename) |> Otel.Config.Parser.parse_file!()
  end
end
