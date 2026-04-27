defmodule Otel.Config.SchemaTest do
  # async: false because the schema-cache tests below mutate
  # `:persistent_term`, which is shared with every other suite that
  # touches `Otel.Config.Schema` (notably `Otel.ConfigTest.load!/0`).
  # Coverage runs surfaced this race: when ConfigTest happened to
  # run first it warmed the cache, leaving the `compile_and_cache`
  # cold-cache branch unhit by the schema-specific tests.
  use ExUnit.Case, async: false

  @cache_key {Otel.Config.Schema, :compiled_schema}
  @fixtures_dir Path.expand("../../fixtures/v1.0.0", __DIR__)

  describe "validate!/1 — valid models from v1.0.0 fixtures" do
    test "otel-getting-started.yaml validates after parsing" do
      assert :ok =
               "otel-getting-started.yaml"
               |> load_fixture()
               |> Otel.Config.Parser.parse_string!()
               |> Otel.Config.Schema.validate!()
    end

    test "otel-sdk-config.yaml (comprehensive example) validates" do
      assert :ok =
               "otel-sdk-config.yaml"
               |> load_fixture()
               |> Otel.Config.Parser.parse_string!()
               |> Otel.Config.Schema.validate!()
    end

    test "otel-sdk-migration-config.yaml validates AFTER substitution" do
      # Migration config uses ${OTEL_*:-default} for nearly every
      # field. Schema expects native types (boolean, integer), so
      # substitution MUST run first — this test covers the full
      # Substitution → Parser → Schema pipeline.
      assert :ok =
               "otel-sdk-migration-config.yaml"
               |> load_fixture()
               |> Otel.Config.Substitution.substitute!()
               |> Otel.Config.Parser.parse_string!()
               |> Otel.Config.Schema.validate!()
    end
  end

  describe "validate!/1 — error cases" do
    test "raises when required field has wrong type" do
      # `file_format` is declared as string in the schema.
      assert_raise ArgumentError, ~r/file_format/, fn ->
        Otel.Config.Schema.validate!(%{"file_format" => 42})
      end
    end

    test "error message lists path and rule" do
      message =
        try do
          Otel.Config.Schema.validate!(%{"file_format" => 42})
          flunk("expected ArgumentError")
        rescue
          e in ArgumentError -> Exception.message(e)
        end

      assert message =~ "opentelemetry-configuration v1.0.0 schema"
      assert message =~ "file_format"
      assert message =~ "type"
    end

    test "raises on multiple violations and lists each" do
      bad = %{
        "file_format" => 42,
        "tracer_provider" => %{
          "sampler" => %{
            "always_on" => "this should be a map or null, not a string"
          }
        }
      }

      message =
        try do
          Otel.Config.Schema.validate!(bad)
          flunk("expected ArgumentError")
        rescue
          e in ArgumentError -> Exception.message(e)
        end

      assert message =~ "file_format"
      assert message =~ "always_on"
    end
  end

  describe "schema caching" do
    test "first call with cold persistent_term hits the compile_and_cache branch" do
      # Coverage-driven: explicitly evict the cache so the
      # `compile_and_cache/0` branch executes regardless of which
      # other suite happened to populate the persistent_term key
      # earlier in the test run.
      :persistent_term.erase(@cache_key)
      refute :persistent_term.get(@cache_key, nil)

      assert :ok = Otel.Config.Schema.validate!(%{"file_format" => "1.0"})
      assert :persistent_term.get(@cache_key, nil)
    end

    test "second call reuses the persistent_term-cached compiled schema" do
      # Cache is already warm from the first test (or some other
      # validate! caller); verify the warm-cache branch is hit
      # without re-compiling.
      assert :ok = Otel.Config.Schema.validate!(%{"file_format" => "1.0"})
      assert :persistent_term.get(@cache_key, nil)
    end
  end

  describe "error message formatting" do
    test "root-level violation (missing required field) renders as '(root)'" do
      # `file_format` is a required top-level field per the schema;
      # an empty model triggers a root-level error whose path is
      # `[]`, hitting `format_path([])` which renders "(root)".
      message =
        try do
          Otel.Config.Schema.validate!(%{})
          flunk("expected ArgumentError")
        rescue
          e in ArgumentError -> Exception.message(e)
        end

      assert message =~ "(root)"
    end

    test "many violations are truncated with a trailing '... (N more)' line" do
      # Build a model that intentionally produces lots of `type`
      # errors — at least 11 so the >10-cap suffix kicks in. Each
      # processor entry violates batch.exporter.otlp_http.endpoint
      # type (must be string).
      bad_processors =
        for i <- 1..15 do
          %{
            "batch" => %{
              "exporter" => %{
                "otlp_http" => %{
                  "endpoint" => i,
                  "headers" => i,
                  "compression" => i,
                  "timeout" => "not_a_number"
                }
              }
            }
          }
        end

      bad = %{
        "file_format" => "1.0",
        "tracer_provider" => %{"processors" => bad_processors}
      }

      message =
        try do
          Otel.Config.Schema.validate!(bad)
          flunk("expected ArgumentError")
        rescue
          e in ArgumentError -> Exception.message(e)
        end

      assert message =~ "more)"
    end
  end

  @spec load_fixture(filename :: String.t()) :: binary()
  defp load_fixture(filename) do
    @fixtures_dir |> Path.join(filename) |> File.read!()
  end
end
