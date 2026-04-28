defmodule Otel.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/yangbancode/otel"

  def project do
    [
      app: :otel,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [
        summary: [threshold: 95],
        ignore_modules: [
          ~r/^Opentelemetry\.Proto\./
        ]
      ],
      elixirc_options: [warnings_as_errors: true],
      description: description(),
      package: package(),
      source_url: @repo_url,
      homepage_url: @repo_url
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
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "OpenTelemetry implementation for Elixir — API, SDK, OTLP exporters, " <>
      "declarative config, semantic conventions, and Logger bridge in a single package."
  end

  defp package do
    [
      licenses: ["Unlicense"],
      links: %{"GitHub" => @repo_url},
      files: ~w(lib priv mix.exs README.md LICENSE .formatter.exs)
    ]
  end
end
