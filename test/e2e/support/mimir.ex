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

  @doc """
  Mimir `/api/v1/query` URL for the cardinality overflow series.

  Per `metrics/sdk.md` §Cardinality Limits, the overflow
  attribute set MUST consist of a single attribute
  `otel.metric.overflow=true` — meaning the synthesized
  overflow series carries no `e2e_id` label, so the regular
  `query/2` selector (`metric{e2e_id="..."}`) filters it out.
  This selector keys on the metric name (already unique per
  test via `e2e_id` suffix) plus the overflow label.
  """
  @spec query_overflow(metric :: String.t()) :: String.t()
  def query_overflow(metric) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: 9090,
      path: "/api/v1/query",
      query: URI.encode_query(query: ~s(#{metric}{otel_metric_overflow="true"}))
    }
    |> URI.to_string()
  end

  @doc """
  Mimir `/api/v1/query_exemplars` URL — exemplar lookup.

  Inline exemplars on the regular `/api/v1/query` envelope are
  not guaranteed across LGTM versions; this dedicated endpoint
  is the contract-preserving way to ask "did this metric carry
  exemplars, and if so, with what trace_id?".
  """
  @spec query_exemplars(e2e_id :: String.t(), metric :: String.t()) :: String.t()
  def query_exemplars(e2e_id, metric) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: 9090,
      path: "/api/v1/query_exemplars",
      query: URI.encode_query(query: ~s(#{metric}{e2e_id="#{e2e_id}"}))
    }
    |> URI.to_string()
  end
end
