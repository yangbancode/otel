defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) query helpers.
  """

  @base "http://localhost:3200"

  @doc """
  Polls Tempo's `/api/search?tags=e2e.id=<e2e_id>` until at least one
  trace matches.
  """
  @spec find(e2e_id :: String.t(), opts :: keyword()) :: Otel.E2E.HTTP.result()
  def find(e2e_id, opts \\ []) do
    url = "#{@base}/api/search?tags=#{URI.encode_www_form("e2e.id=#{e2e_id}")}&limit=1"

    Otel.E2E.HTTP.poll(
      url,
      fn
        %{"traces" => [_ | _] = traces} -> {:ok, traces}
        _ -> :empty
      end,
      opts
    )
  end
end
