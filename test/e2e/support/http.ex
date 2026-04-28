defmodule Otel.E2E.HTTP do
  @moduledoc """
  Thin `:httpc` wrapper used by e2e backend query helpers.
  """

  @type result :: {:ok, body :: String.t()} | {:error, term()}

  @doc "GETs `url`, returns `{:ok, body}` on HTTP 200, `{:error, _}` otherwise."
  @spec get(url :: String.t()) :: result()
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
end
