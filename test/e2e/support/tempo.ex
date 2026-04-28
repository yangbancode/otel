defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) URL builders.
  """

  @base "http://localhost:3200"

  @doc "Tempo `/api/search` URL for the given e2e_id."
  @spec find(e2e_id :: String.t()) :: String.t()
  def find(e2e_id) do
    "#{@base}/api/search?tags=#{URI.encode_www_form("e2e.id=#{e2e_id}")}&limit=1"
  end
end
