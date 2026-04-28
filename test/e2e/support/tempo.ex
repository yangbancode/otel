defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) query helpers.
  """

  @base "http://localhost:3200"

  @doc """
  Polls Tempo's `/api/search?tags=e2e.id=<marker>` endpoint until
  the marker is found in the response body or the timeout elapses.
  """
  @spec find(marker :: String.t(), opts :: keyword()) :: Otel.E2E.Polling.result()
  def find(marker, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)

    Otel.E2E.Polling.until(timeout, fn ->
      url = "#{@base}/api/search?tags=#{URI.encode_www_form("e2e.id=#{marker}")}&limit=1"

      with {:ok, body} <- Otel.E2E.HTTP.get(url),
           true <- String.contains?(body, marker) do
        {:ok, body}
      else
        _ -> :retry
      end
    end)
  end
end
