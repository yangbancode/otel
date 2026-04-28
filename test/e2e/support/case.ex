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
  @spec scope() :: Otel.API.InstrumentationScope.t()
  def scope, do: @scope

  @doc "Force-flushes all three SDK providers (Tracer / Logger / Meter)."
  @spec flush() :: :ok
  def flush do
    Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)
    Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)
    Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
    :ok
  end

  using do
    quote location: :keep do
      import Otel.E2E.Case, only: [scope: 0, flush: 0]
      import Otel.E2E.HTTP, only: [poll: 1]
      alias Otel.E2E.{Loki, Mimir, Tempo}

      @moduletag :e2e
    end
  end

  setup do
    {:ok, e2e_id: Integer.to_string(System.unique_integer([:positive, :monotonic]))}
  end
end
