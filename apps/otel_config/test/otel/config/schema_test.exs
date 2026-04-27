defmodule Otel.Config.SchemaTest do
  use ExUnit.Case, async: true

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
    test "second call reuses the persistent_term-cached compiled schema" do
      # Side-effect-based check: warm the cache, then verify the
      # persistent_term key is set so subsequent calls bypass the
      # file read + JSONSchex.compile path.
      assert :ok = Otel.Config.Schema.validate!(%{"file_format" => "1.0"})
      assert :persistent_term.get({Otel.Config.Schema, :compiled_schema}, nil)
    end
  end

  describe "error message formatting" do
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
