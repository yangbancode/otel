defmodule Otel.E2E.Mimir do
  @moduledoc """
  Mimir / Prometheus (metric backend) query helpers.

  OTel → Prometheus naming reminder:

  - dots become underscores (`http.requests` → `http_requests`)
  - counters get a `_total` suffix (`http_requests_total`)
  - attribute keys become labels (`http.method` → `http_method`)
  """

  @base "http://localhost:9090"

  @doc """
  Polls Mimir's `/api/v1/query` for `metric{e2e_id="<e2e_id>"}` until
  at least one series matches.
  """
  @spec find_metric(metric :: String.t(), e2e_id :: String.t()) :: Otel.E2E.HTTP.result()
  def find_metric(metric, e2e_id) do
    query = ~s(#{metric}{e2e_id="#{e2e_id}"})

    Otel.E2E.HTTP.poll("#{@base}/api/v1/query?query=#{URI.encode_www_form(query)}")
  end
end
