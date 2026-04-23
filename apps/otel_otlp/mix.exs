defmodule Otel.OTLP.MixProject do
  use Mix.Project

  def project do
    [
      app: :otel_otlp,
      version: "0.1.0",
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [
        summary: [threshold: 95],
        ignore_modules: [
          ~r/^Opentelemetry\.Proto\./
        ]
      ],
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :public_key]
    ]
  end

  defp deps do
    [
      {:otel_sdk, in_umbrella: true},
      {:protobuf, "~> 0.16.0"}
    ]
  end
end
