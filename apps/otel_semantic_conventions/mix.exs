defmodule Otel.SemConv.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/yangbancode/otel"
  @source_url "#{@repo_url}/tree/main/apps/otel_semantic_conventions"
  @changelog_url "#{@repo_url}/blob/main/apps/otel_semantic_conventions/CHANGELOG.md"

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
      test_coverage: [summary: [threshold: 95]],
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
    "OpenTelemetry Semantic Conventions for Elixir — " <>
      "auto-generated attribute and metric key constants from the OpenTelemetry spec."
  end

  defp package do
    [
      licenses: ["Unlicense"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @changelog_url
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        {"README.md", title: "README.md"},
        {"CHANGELOG.md", title: "CHANGELOG"},
        {"LICENSE", title: "LICENSE"}
      ],
      source_url: @source_url,
      source_ref: "otel_semantic_conventions-v#{@version}",
      source_url_pattern:
        "#{@repo_url}/blob/otel_semantic_conventions-v#{@version}/apps/otel_semantic_conventions/%{path}#L%{line}",
      before_closing_head_tag: &before_closing_head_tag/1,
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

  defp before_closing_head_tag(:html) do
    ~S(<meta name="exdoc:autocomplete-limit" content="25">)
  end

  defp before_closing_head_tag(_), do: ""
end
