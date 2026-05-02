defmodule Otel.MixProject do
  use Mix.Project

  @version "0.2.0"
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

  defp elixirc_paths(:test), do: ["lib", "test/e2e/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/trace.md",
        "docs/log.md",
        "docs/metrics.md",
        "docs/configuration.md",
        "docs/logger-handler.md",
        "docs/e2e.md",
        "LICENSE",
        "NOTICE"
      ],
      groups_for_extras: [
        "How-to": ["docs/trace.md", "docs/log.md", "docs/metrics.md"],
        Configuration: ["docs/configuration.md", "docs/logger-handler.md"],
        Testing: ["docs/e2e.md"],
        Legal: ["LICENSE", "NOTICE"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :public_key],
      mod: {Otel.SDK.Application, []}
    ]
  end

  defp deps do
    [
      # Runtime — required for OTLP/HTTP exporters
      {:protobuf, "~> 0.16.0"},
      # Runtime — required for Otel.Config (declarative YAML config)
      {:yaml_elixir, "~> 2.12"},
      {:jsonschex, "~> 0.5.0"},
      # Dev / test only
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp description do
    "Pure Elixir implementation of OpenTelemetry"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url},
      files: ~w(docs lib priv mix.exs README.md LICENSE NOTICE .formatter.exs)
    ]
  end
end
