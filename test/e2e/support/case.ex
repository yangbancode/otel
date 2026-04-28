defmodule Otel.E2E.Case do
  @moduledoc """
  ExUnit case template for end-to-end tests against the local
  Grafana LGTM stack.

  Each test gets a unique `:marker` (timestamp + random) in its
  context so test data can be located in Tempo / Loki / Mimir
  without colliding with other concurrent or recent runs.

  All e2e modules carry `@moduletag :e2e`, so they are excluded
  from the default `mix test` run via
  `ExUnit.start(exclude: [:e2e])` in `test/test_helper.exs`. To
  run them: `docker compose up -d` then
  `mix test --only e2e test/e2e/`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Otel.E2E.Emitter
      alias Otel.E2E.{Loki, Mimir, Tempo}

      @moduletag :e2e
    end
  end

  setup do
    {:ok, marker: marker()}
  end

  defp marker do
    "e2e-#{:os.system_time(:millisecond)}-#{:rand.uniform(1_000_000)}"
  end
end
