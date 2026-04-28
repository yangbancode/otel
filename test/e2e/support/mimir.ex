defmodule Otel.E2E.Mimir do
  @moduledoc """
  Mimir / Prometheus (metric backend) URL builders.

  OTel → Prometheus naming reminder:

  - dots become underscores (`http.requests` → `http_requests`)
  - counters get a `_total` suffix (`http_requests_total`)
  - attribute keys become labels (`http.method` → `http_method`)
  """

  @doc "Mimir `/api/v1/query` URL for the given metric + e2e_id."
  @spec find_metric(metric :: String.t(), e2e_id :: String.t()) :: String.t()
  def find_metric(metric, e2e_id) do
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
