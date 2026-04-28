defmodule Otel.E2E.HTTP do
  @moduledoc """
  HTTP helpers for e2e backend queries — `:httpc` GET plus a
  poll-until-non-empty driver.

  `poll/1` knows the two response shapes returned by the LGTM
  query APIs:

  - `%{"traces" => [_ | _]}` — Tempo
  - `%{"data" => %{"result" => [_ | _]}}` — Loki / Mimir (Prometheus)

  When neither pattern matches (i.e. the result list is empty),
  it retries every 1 s up to 3 attempts total.
  """

  @type result :: {:ok, [term()]} | {:error, term()}

  @interval_ms 1_000
  @timeout_ms 5_000
  @max_attempts 3

  @doc """
  Repeatedly GETs `url` until the JSON body has a non-empty result
  list (Tempo `traces` or Prometheus-style `data.result`). Retries
  every 1 s up to 3 attempts; returns `{:error, :timeout}` after
  the final empty response.
  """
  @spec poll(url :: String.t()) :: result()
  def poll(url) do
    loop(url, @max_attempts)
  end

  @spec loop(url :: String.t(), attempts_left :: non_neg_integer()) :: result()
  defp loop(_url, 0), do: {:error, :timeout}

  defp loop(url, attempts_left) do
    case fetch(url) do
      {:ok, %{"traces" => [_ | _] = results}} ->
        {:ok, results}

      {:ok, %{"data" => %{"result" => [_ | _] = results}}} ->
        {:ok, results}

      _ ->
        Process.sleep(@interval_ms)
        loop(url, attempts_left - 1)
    end
  end

  @spec fetch(url :: String.t()) :: {:ok, term()} | {:error, term()}
  defp fetch(url) do
    with {:ok, body} <- get(url) do
      Jason.decode(body)
    end
  end

  @spec get(url :: String.t()) :: {:ok, String.t()} | {:error, term()}
  defp get(url) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, @timeout_ms}], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, to_string(body)}

      {:ok, {{_, status, _}, _, body}} ->
        {:error, {:status, status, to_string(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
