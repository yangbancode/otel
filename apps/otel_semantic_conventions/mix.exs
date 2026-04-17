defmodule Otel.SemConv.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/yangbancode/otel"
  @source_url "#{@repo_url}/tree/main/apps/otel_semantic_conventions"

  def project do
    [
      app: :otel_semantic_conventions,
      version: @version,
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [summary: [threshold: 100]],
      elixirc_options: [warnings_as_errors: true],
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @repo_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Pure Elixir implementation of OpenTelemetry Semantic Conventions. " <>
      "Part of the Otel umbrella project, a pure Elixir implementation of OpenTelemetry."
  end

  defp package do
    [
      licenses: ["Unlicense"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        {"README.md", title: "README.md"},
        {"LICENSE", title: "LICENSE"}
      ],
      source_url: @source_url,
      source_ref: "otel_semantic_conventions-v#{@version}",
      source_url_pattern:
        "#{@repo_url}/blob/otel_semantic_conventions-v#{@version}/apps/otel_semantic_conventions/%{path}#L%{line}",
      groups_for_modules: [
        Attributes: ~r/^Otel\.SemConv\.Attributes\./,
        Metrics: ~r/^Otel\.SemConv\.Metrics\./
      ],
      nest_modules_by_prefix: [
        Otel.SemConv.Attributes,
        Otel.SemConv.Metrics
      ]
    ]
  end
end
