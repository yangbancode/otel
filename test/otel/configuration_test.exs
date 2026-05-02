defmodule Otel.ConfigurationTest do
  # Touches OTEL_CONFIG_FILE — must not run async with anything
  # that reads the same env var.
  use ExUnit.Case, async: false

  @fixtures_dir Path.expand("../fixtures/v1.0.0", __DIR__)
  @env_var "OTEL_CONFIG_FILE"

  setup do
    on_exit(fn -> System.delete_env(@env_var) end)
    :ok
  end

  describe "config_file_set?/0" do
    test "false when OTEL_CONFIG_FILE is unset" do
      assert Otel.Configuration.config_file_set?() == false
    end

    test "false when OTEL_CONFIG_FILE is empty string (spec L60)" do
      System.put_env(@env_var, "")
      assert Otel.Configuration.config_file_set?() == false
    end

    test "true when OTEL_CONFIG_FILE points at a path" do
      System.put_env(@env_var, "/some/path/config.yaml")
      assert Otel.Configuration.config_file_set?() == true
    end
  end

  describe "load!/0" do
    test "reads OTEL_CONFIG_FILE and runs the full pipeline → SDK provider configs" do
      System.put_env(@env_var, Path.join(@fixtures_dir, "otel-getting-started.yaml"))

      assert %{trace: trace, metrics: metrics, logs: logs} = Otel.Configuration.load!()

      # Trace pipeline produced batch(otlp_http) processor
      assert [{Otel.SDK.Trace.SpanProcessor.Batch, _}] = trace.processors

      # Metrics produced periodic reader
      assert [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, _}] = metrics.readers

      # Logs produced batch processor
      assert [{Otel.SDK.Logs.LogRecordProcessor.Batch, _}] = logs.processors
    end

    test "raises when OTEL_CONFIG_FILE is unset" do
      assert_raise ArgumentError, ~r/OTEL_CONFIG_FILE is not set/, fn ->
        Otel.Configuration.load!()
      end
    end

    test "raises when the file does not exist" do
      System.put_env(@env_var, "/nonexistent/otel-config.yaml")

      # `load!/0` calls `File.read!/1` directly (the substitution
      # layer needs the raw text), so a missing path raises
      # `File.Error` rather than the parser's
      # `YamlElixir.FileNotFoundError`.
      assert_raise File.Error, fn ->
        Otel.Configuration.load!()
      end
    end
  end
end
