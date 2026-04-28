defmodule Otel.E2E.Mimir do
  @moduledoc """
  Mimir / Prometheus (metric backend) URL builders.

  OTel → Prometheus naming reminder:

  - dots become underscores (`http.requests` → `http_requests`)
  - counters get a `_total` suffix (`http_requests_total`)
  - attribute keys become labels (`http.method` → `http_method`)
  """

  @doc "Mimir `/api/v1/query` URL for the given e2e_id + metric."
  @spec query(e2e_id :: String.t(), metric :: String.t()) :: String.t()
  def query(e2e_id, metric) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: 9090,
      path: "/api/v1/query",
      query: URI.encode_query(query: ~s(#{metric}{e2e_id="#{e2e_id}"}))
    }
    |> URI.to_string()
  end
end
