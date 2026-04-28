defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) query helpers.
  """

  @base "http://localhost:3200"

  @doc """
  Polls Tempo's `/api/search?tags=e2e.id=<e2e_id>` endpoint until
  the e2e_id is found in the response body or the timeout elapses.
  """
  @spec find(e2e_id :: String.t(), opts :: keyword()) :: Otel.E2E.Polling.result()
  def find(e2e_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)

    Otel.E2E.Polling.until(timeout, fn ->
      url = "#{@base}/api/search?tags=#{URI.encode_www_form("e2e.id=#{e2e_id}")}&limit=1"

      with {:ok, body} <- Otel.E2E.HTTP.get(url),
           true <- String.contains?(body, e2e_id) do
        {:ok, body}
      else
        _ -> :retry
      end
    end)
  end
end
