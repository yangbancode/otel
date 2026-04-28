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
  Polls Mimir's `/api/v1/query` for `metric{e2e_id="<e2e_id>"}`
  until a matching series is returned.
  """
  @spec find_metric(metric :: String.t(), e2e_id :: String.t(), opts :: keyword()) ::
          Otel.E2E.Polling.result()
  def find_metric(metric, e2e_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 15_000)

    Otel.E2E.Polling.until(timeout, fn ->
      query = ~s(#{metric}{e2e_id="#{e2e_id}"})
      url = "#{@base}/api/v1/query?query=#{URI.encode_www_form(query)}"

      with {:ok, body} <- Otel.E2E.HTTP.get(url),
           true <- String.contains?(body, e2e_id) do
        {:ok, body}
      else
        _ -> :retry
      end
    end)
  end
end
