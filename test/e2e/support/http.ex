defmodule Otel.E2E.HTTP do
  @moduledoc """
  HTTP helpers for e2e backend queries.

  Three layered functions, each with a single responsibility:

  - `get/1` — raw GET, returns the response body as a string.
    Use when the test needs the unstructured payload (e.g.
    Tempo's `/api/traces/{id}` returns OTLP-shaped JSON the
    test decodes itself).
  - `fetch/1` — `get/1` + JSON decode + result-list extraction.
    Returns `{:ok, results}` for both populated **and empty**
    backends — empty is `{:ok, []}`, not an error. Use for
    absence assertions, or when the test wants a single-shot
    check.
  - `poll/1` — `fetch/1` retried every 3 s for up to 10
    attempts, succeeding the moment the result list is
    non-empty. Use for positive scenarios where Tempo's
    indexing lag means the first fetch is often empty.

  Two response shapes are recognised by `fetch/1`:

  - `%{"traces" => [_]}` — Tempo `/api/search`.
  - `%{"data" => %{"result" => [_]}}` — Loki / Mimir
    (Prometheus-style response envelope).

  Anything else (including connection errors) decodes to an
  empty list, so `fetch/1` returning `{:ok, []}` is the
  unambiguous "backend has nothing for me" signal.
  """

  @type result :: {:ok, [term()]} | {:error, term()}

  @interval_ms 3_000
  @timeout_ms 5_000
  @max_attempts 10

  @doc """
  Single fetch. Returns the result list — empty if the backend
  has no records.

  Pair with pattern matching for absence checks:

      assert {:ok, []} = fetch(Tempo.search(e2e_id))

  Or with `poll/1` when the test needs to wait through ingest
  lag:

      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
  """
  @spec fetch(url :: String.t()) :: result()
  def fetch(url) do
    with {:ok, body} <- get(url),
         {:ok, decoded} <- Jason.decode(body) do
      {:ok, extract_results(decoded)}
    end
  end

  @doc """
  Repeatedly `fetch/1`s `url` until the result list is
  non-empty. Retries every 3 s for up to 10 attempts (≈30 s
  budget); returns `{:error, :timeout}` after the final empty
  response.

  The 3 s interval matches Tempo's `/api/search` indexing
  cadence — polling faster just queries an empty index
  repeatedly while the backend catches up.
  """
  @spec poll(url :: String.t()) :: result()
  def poll(url), do: loop(url, @max_attempts)

  @doc "Single-shot GET. Returns the raw body."
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

  @spec extract_results(decoded :: term()) :: [term()]
  defp extract_results(%{"traces" => list}) when is_list(list), do: list
  defp extract_results(%{"data" => %{"result" => list}}) when is_list(list), do: list
  defp extract_results(_), do: []

  @spec loop(url :: String.t(), attempts_left :: non_neg_integer()) :: result()
  defp loop(_url, 0), do: {:error, :timeout}

  defp loop(url, attempts_left) do
    case fetch(url) do
      {:ok, [_ | _]} = ok ->
        ok

      _ ->
        Process.sleep(@interval_ms)
        loop(url, attempts_left - 1)
    end
  end
end
