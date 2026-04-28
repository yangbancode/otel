defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) URL builders.
  """

  @doc "Tempo `/api/search` URL for the given e2e_id."
  @spec query(e2e_id :: String.t()) :: String.t()
  def query(e2e_id) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: 3200,
      path: "/api/search",
      query: URI.encode_query(tags: "e2e.id=#{e2e_id}", limit: 1)
    }
    |> URI.to_string()
  end
end
