defmodule Otel.Logger.Handler.MixProject do
  use Mix.Project

  def project do
    [
      app: :otel_logger_handler,
      version: "0.1.0",
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [summary: [threshold: 95]],
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:otel_api, in_umbrella: true}
    ]
  end
end
