defmodule Otel.SDK.MixProject do
  use Mix.Project

  def project do
    [
      app: :otel_sdk,
      version: "0.1.0",
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [
        threshold: 100,
        ignore_modules: [Otel.SDK.Application]
      ],
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Otel.SDK.Application, []}
    ]
  end

  defp deps do
    [
      {:otel_api, in_umbrella: true}
    ]
  end
end
