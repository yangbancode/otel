defmodule Otel.E2E.HTTP do
  @moduledoc """
  HTTP helpers for e2e backend queries — `:httpc` GET plus a
  poll-until-match driver that wraps fetch + JSON decode + caller-
  supplied pattern match in a single call.

  Polling cadence: up to 3 attempts, 1 s apart, with a 5 s timeout
  on each individual HTTP request.
  """

  @type result :: {:ok, term()} | {:error, term()}

  @interval_ms 1_000
  @timeout_ms 5_000
  @max_attempts 3

  @doc "GETs `url`. Returns `{:ok, body}` on HTTP 200, `{:error, _}` otherwise."
  @spec get(url :: String.t()) :: {:ok, String.t()} | {:error, term()}
  def get(url) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, @timeout_ms}], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, to_string(body)}

      {:ok, {{_, status, _}, _, body}} ->
        {:error, {:status, status, to_string(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Repeatedly GETs `url`, JSON-decodes the body, and runs `match_fn`
  on the decoded payload. Returns `{:ok, value}` the first time
  `match_fn` returns `{:ok, value}`. Otherwise retries every 1 s up
  to 3 attempts total, then `{:error, :timeout}`.
  """
  @spec poll(url :: String.t(), match_fn :: (term() -> {:ok, term()} | term())) :: result()
  def poll(url, match_fn) do
    loop(url, match_fn, @max_attempts)
  end

  defp loop(_url, _match_fn, 0), do: {:error, :timeout}

  defp loop(url, match_fn, attempts_left) do
    with {:ok, body} <- get(url),
         {:ok, decoded} <- Jason.decode(body),
         {:ok, value} <- match_fn.(decoded) do
      {:ok, value}
    else
      _ ->
        Process.sleep(@interval_ms)
        loop(url, match_fn, attempts_left - 1)
    end
  end
end
