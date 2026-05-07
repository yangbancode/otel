defmodule Otel.E2E.Mimir do
  @moduledoc """
  Mimir / Prometheus (metric backend) URL builders.

  OTel → Prometheus naming reminder:

  - dots become underscores (`http.requests` → `http_requests`)
  - counters get a `_total` suffix (`http_requests_total`)
  - attribute keys become labels (`http.method` → `http_method`)
  """

  @doc "Mimir `/api/v1/query` URL for a raw PromQL expression."
  @spec query(promql :: String.t()) :: String.t()
  def query(promql) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: 9090,
      path: "/api/v1/query",
      query: URI.encode_query(query: promql)
    }
    |> URI.to_string()
  end

  @doc """
  Convenience wrapper: builds `metric{e2e_id="..."}` and
  delegates to `query/1`. Most metric tests want this — the
  `e2e_id` selector keeps each test's series separated under
  a shared metric name.
  """
  @spec query(e2e_id :: String.t(), metric :: String.t()) :: String.t()
  def query(e2e_id, metric), do: query(~s(#{metric}{e2e_id="#{e2e_id}"}))

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

  @doc """
  Extracts the numeric value from a single PromQL `result`
  entry. PromQL serialises numbers as strings (both ints and
  floats); this returns a float so callers can compare without
  branching on type.

  ## Example

      {:ok, [result | _]} = poll(Mimir.query(e2e_id, "metric"))
      assert Mimir.value(result) == 42.0
  """
  @spec value(result :: map()) :: float()
  def value(%{"value" => [_timestamp, str]}) when is_binary(str) do
    {n, ""} = Float.parse(str)
    n
  end

  @doc """
  Returns the label value for `key` on a single PromQL result
  entry. Useful when asserting that a tagged series carries
  the expected label values.
  """
  @spec label(result :: map(), key :: String.t()) :: String.t() | nil
  def label(%{"metric" => labels}, key), do: Map.get(labels, key)
end
