defmodule Otel.E2E.Polling do
  @moduledoc """
  Poll-until-success helper for backends that ingest data
  asynchronously (Tempo / Loki / Mimir all have non-zero ingestion
  lag after OTLP receive).
  """

  @type result :: {:ok, term()} | {:error, :timeout}

  @doc """
  Calls `fun` repeatedly every `interval` ms until it returns
  `{:ok, value}` or until `timeout` ms elapses.

  `fun` returns:

  - `{:ok, value}` — success, returned to caller
  - `:retry` — keep polling
  """
  @spec until(
          timeout :: non_neg_integer(),
          interval :: non_neg_integer(),
          fun :: (-> {:ok, term()} | :retry)
        ) ::
          result()
  def until(timeout, interval \\ 500, fun) when is_function(fun, 0) do
    deadline = System.monotonic_time(:millisecond) + timeout
    loop(deadline, interval, fun)
  end

  defp loop(deadline, interval, fun) do
    case fun.() do
      {:ok, value} ->
        {:ok, value}

      :retry ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(interval)
          loop(deadline, interval, fun)
        end
    end
  end
end
