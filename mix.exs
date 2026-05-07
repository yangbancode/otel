defmodule Otel.MixProject do
  use Mix.Project

  @version "0.4.1"
  @repo_url "https://github.com/yangbancode/otel"

  def project do
    [
      app: :otel,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.github": :test
      ],
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [plt_add_apps: [:ex_unit]],
      description: description(),
      package: package(),
      source_url: @repo_url,
      homepage_url: @repo_url,
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/e2e/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "LICENSE",
        "NOTICE"
      ],
      groups_for_extras: [
        Legal: ["LICENSE", "NOTICE"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Otel.Application, []}
    ]
  end

  defp deps do
    [
      # Runtime — required for OTLP/HTTP exporters
      {:protobuf, "~> 0.16.0"},
      {:req, "~> 0.5"},
      # Runtime — `:telemetry.attach/4` + `:telemetry.span/3`
      # are used directly by `Otel.TelemetryReporter` and
      # `Otel.TelemetryTracer`, so list it explicitly even
      # though it would arrive transitively via
      # `telemetry_metrics`.
      {:telemetry, "~> 1.0"},
      # Runtime — `Telemetry.Metrics` specs consumed by
      # `Otel.TelemetryReporter`.
      {:telemetry_metrics, "~> 1.0"},
      # Dev / test only
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp description do
    "Pure Elixir, OpenTelemetry-compatible"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url},
      files: ~w(lib mix.exs README.md LICENSE NOTICE .formatter.exs)
    ]
  end
end
