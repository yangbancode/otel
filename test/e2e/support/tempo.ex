defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) query helpers.
  """

  @base "http://localhost:3200"

  @doc """
  Polls Tempo's `/api/search?tags=e2e.id=<e2e_id>` until at least one
  trace matches. Empty results (`{"traces": []}`) trigger a retry;
  any other shape is returned as-is.
  """
  @spec find(e2e_id :: String.t(), opts :: keyword()) :: Otel.E2E.Polling.result()
  def find(e2e_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)

    Otel.E2E.Polling.until(timeout, fn ->
      url = "#{@base}/api/search?tags=#{URI.encode_www_form("e2e.id=#{e2e_id}")}&limit=1"

      with {:ok, body} <- Otel.E2E.HTTP.get(url),
           {:ok, %{"traces" => [_ | _] = traces}} <- Jason.decode(body) do
        {:ok, traces}
      else
        _ -> :retry
      end
    end)
  end
end
