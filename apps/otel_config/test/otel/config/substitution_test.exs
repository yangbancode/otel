defmodule Otel.Config.SubstitutionTest do
  # Touches real OS env vars — must not run async with other
  # env-mutating suites.
  use ExUnit.Case, async: false

  @vars [
    "OTEL_TEST_FOO",
    "OTEL_TEST_BAR",
    "OTEL_TEST_BAZ",
    "OTEL_TEST_EMPTY",
    "OTEL_TEST_DEFINED"
  ]

  setup do
    on_exit(fn -> Enum.each(@vars, &System.delete_env/1) end)
    :ok
  end

  describe "basic substitution" do
    test "${VAR} substitutes a defined env var" do
      System.put_env("OTEL_TEST_FOO", "hello")
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_FOO}") == "hello"
    end

    test "${VAR} returns empty string when undefined and no default" do
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_FOO}") == ""
    end

    test "${VAR} returns empty string when defined but empty" do
      System.put_env("OTEL_TEST_EMPTY", "")
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_EMPTY}") == ""
    end

    test "${env:VAR} works the same as ${VAR}" do
      System.put_env("OTEL_TEST_FOO", "hello")
      assert Otel.Config.Substitution.substitute!("${env:OTEL_TEST_FOO}") == "hello"
    end
  end

  describe ":- default value" do
    test "${VAR:-default} uses default when undefined" do
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_FOO:-fallback}") == "fallback"
    end

    test "${VAR:-default} uses default when empty" do
      System.put_env("OTEL_TEST_EMPTY", "")
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_EMPTY:-fallback}") == "fallback"
    end

    test "${VAR:-default} uses VAR value when defined" do
      System.put_env("OTEL_TEST_DEFINED", "real")
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_DEFINED:-fallback}") == "real"
    end

    test "${env:VAR:-default} works with explicit env prefix" do
      assert Otel.Config.Substitution.substitute!("${env:OTEL_TEST_FOO:-fallback}") == "fallback"
    end

    test "default value can contain colons and other punctuation" do
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_FOO:-http://localhost:4318}") ==
               "http://localhost:4318"
    end

    test "default value can be empty" do
      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_FOO:-}") == ""
    end
  end

  describe "$$ escape" do
    test "$$ produces a literal $" do
      assert Otel.Config.Substitution.substitute!("$$") == "$"
    end

    test "$${VAR} produces a literal ${VAR} (no substitution)" do
      System.put_env("OTEL_TEST_FOO", "hello")
      assert Otel.Config.Substitution.substitute!("$${OTEL_TEST_FOO}") == "${OTEL_TEST_FOO}"
    end

    test "spec pseudocode example: '$${FOO} ${BAR} $${BAZ}' (data-model.md L368-L376)" do
      System.put_env("OTEL_TEST_FOO", "a")
      System.put_env("OTEL_TEST_BAR", "b")
      System.put_env("OTEL_TEST_BAZ", "c")

      input = "$${OTEL_TEST_FOO} ${OTEL_TEST_BAR} $${OTEL_TEST_BAZ}"
      expected = "${OTEL_TEST_FOO} b ${OTEL_TEST_BAZ}"

      assert Otel.Config.Substitution.substitute!(input) == expected
    end
  end

  describe "multiple substitutions in one input" do
    test "concatenated references resolve independently" do
      System.put_env("OTEL_TEST_FOO", "a")
      System.put_env("OTEL_TEST_BAR", "b")

      assert Otel.Config.Substitution.substitute!("${OTEL_TEST_FOO}_${OTEL_TEST_BAR}") == "a_b"
    end
  end

  describe "literal characters pass through" do
    test "input without any substitution is returned unchanged" do
      assert Otel.Config.Substitution.substitute!("hello world: 42") == "hello world: 42"
    end

    test "lone $ (not followed by $ or {) is preserved" do
      assert Otel.Config.Substitution.substitute!("price: $42") == "price: $42"
    end
  end

  describe "error handling — spec data-model.md L378-L382 MUST raise" do
    test "invalid ENV-NAME starting with digit: ${1FOO}" do
      assert_raise ArgumentError, ~r/invalid ENV-NAME/, fn ->
        Otel.Config.Substitution.substitute!("${1FOO}")
      end
    end

    test "invalid ENV-NAME with non-allowed chars: ${API_$KEY}" do
      assert_raise ArgumentError, ~r/invalid ENV-NAME/, fn ->
        Otel.Config.Substitution.substitute!("${API_$KEY}")
      end
    end

    test "unsupported prefix: ${sys:foo}" do
      assert_raise ArgumentError, ~r/unsupported substitution prefix/, fn ->
        Otel.Config.Substitution.substitute!("${sys:foo}")
      end
    end

    test "unterminated substitution: ${VAR (no closing brace)" do
      assert_raise ArgumentError, ~r/unterminated/, fn ->
        Otel.Config.Substitution.substitute!("${OTEL_TEST_FOO")
      end
    end
  end

  describe "integration with the parser" do
    test "migration config substitutes then YAML-parses to typed values" do
      # Mimics the real OTEL_CONFIG_FILE pipeline:
      #   File.read! → Substitution.substitute! → Parser.parse_string!
      # Once substituted, the YAML parser interprets "false" as
      # boolean and "128" as integer (spec MUST L386-L388).
      yaml = """
      file_format: "1.0"
      disabled: ${OTEL_TEST_DISABLED:-false}
      attribute_limits:
        attribute_count_limit: ${OTEL_TEST_LIMIT:-128}
      """

      parsed =
        yaml
        |> Otel.Config.Substitution.substitute!()
        |> Otel.Config.Parser.parse_string!()

      assert parsed["disabled"] == false
      assert parsed["attribute_limits"]["attribute_count_limit"] == 128
    end

    test "v1.0.0 fixture otel-sdk-migration-config.yaml substitutes + parses end-to-end" do
      # Fixture is heavy on `${OTEL_*:-default}` references — was
      # the case that originally exposed the need for this
      # module. After substitution it MUST parse without raising.
      path =
        Path.expand(
          "../../fixtures/v1.0.0/otel-sdk-migration-config.yaml",
          __DIR__
        )

      parsed =
        path
        |> File.read!()
        |> Otel.Config.Substitution.substitute!()
        |> Otel.Config.Parser.parse_string!()

      assert parsed["file_format"] == "1.0"
      # `disabled: ${OTEL_SDK_DISABLED:-false}` resolved to `false`
      assert parsed["disabled"] == false
    end
  end
end
