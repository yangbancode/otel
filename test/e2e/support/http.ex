defmodule Otel.E2E.HTTP do
  @moduledoc """
  HTTP helpers for e2e backend queries — `:httpc` GET plus a
  poll-until-match driver that wraps fetch + JSON decode + caller-
  supplied pattern match in a single call.
  """

  @type result :: {:ok, term()} | {:error, term()}

  @interval 500

  @doc "GETs `url`. Returns `{:ok, body}` on HTTP 200, `{:error, _}` otherwise."
  @spec get(url :: String.t()) :: {:ok, String.t()} | {:error, term()}
  def get(url) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, 5_000}], []) do
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
  `match_fn` returns `{:ok, value}`. Otherwise retries every 500 ms
  until `:timeout` (default 10_000 ms) elapses, then
  `{:error, :timeout}`.
  """
  @spec poll(
          url :: String.t(),
          match_fn :: (term() -> {:ok, term()} | term()),
          opts :: keyword()
        ) :: result()
  def poll(url, match_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)
    deadline = System.monotonic_time(:millisecond) + timeout
    loop(url, match_fn, deadline)
  end

  defp loop(url, match_fn, deadline) do
    with {:ok, body} <- get(url),
         {:ok, decoded} <- Jason.decode(body),
         {:ok, value} <- match_fn.(decoded) do
      {:ok, value}
    else
      _ ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(@interval)
          loop(url, match_fn, deadline)
        end
    end
  end
end
