defmodule Otel.E2E.Case do
  @moduledoc """
  ExUnit case template for end-to-end tests against the local
  Grafana LGTM stack.

  Each test gets a unique `:e2e_id` (BEAM-runtime monotonic
  integer) in its context so test data can be located in Tempo /
  Loki / Mimir without colliding with other concurrent or recent
  runs.

  All e2e modules carry `@moduletag :e2e`, so they are excluded
  from the default `mix test` run via
  `ExUnit.start(exclude: [:e2e])` in `test/test_helper.exs`. To
  run them: `docker compose up -d` then
  `mix test --only e2e test/e2e/`.
  """

  use ExUnit.CaseTemplate

  @scope %Otel.API.InstrumentationScope{name: "e2e", version: "0.1.0"}

  @doc "InstrumentationScope used by every e2e test."
  def scope, do: @scope

  @doc "Force-flushes the SDK TracerProvider."
  def flush_traces, do: Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)

  @doc "Force-flushes the SDK LoggerProvider."
  def flush_logs, do: Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)

  @doc "Force-flushes the SDK MeterProvider."
  def flush_metrics,
    do: Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)

  using do
    quote do
      import Otel.E2E.Case, only: [scope: 0, flush_traces: 0, flush_logs: 0, flush_metrics: 0]
      alias Otel.E2E.{Loki, Mimir, Tempo}

      @moduletag :e2e
    end
  end

  setup do
    {:ok, e2e_id: Integer.to_string(System.unique_integer([:positive, :monotonic]))}
  end
end
