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

  @doc """
  Drains and force-flushes all three SDK exporters directly
  (Span / LogRecord / Metric). The Providers no longer expose
  `force_flush` since lifecycle is delegated to OTP — tests
  reach into the exporters' SDK-internal helpers.
  """
  @spec flush() :: :ok
  def flush do
    Otel.Trace.SpanExporter.force_flush()
    Otel.Logs.LogRecordExporter.force_flush()
    Otel.Metrics.MetricExporter.force_flush()
    :ok
  end

  using do
    quote location: :keep do
      import Otel.E2E.Case, only: [flush: 0]
      import Otel.E2E.HTTP, only: [poll: 1, fetch: 1]
      alias Otel.E2E.{HTTP, Loki, Mimir, Tempo}

      @moduletag :e2e
    end
  end

  setup do
    {:ok, e2e_id: Integer.to_string(System.unique_integer([:positive, :monotonic]))}
  end
end
