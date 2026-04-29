defmodule Otel.E2E.Loki do
  @moduledoc """
  Loki (log backend) URL builders.

  Loki is queried via `/loki/api/v1/query_range` with a LogQL
  expression. Most tests filter on the `e2e_id` substring in
  the rendered line (`query/1`); tests whose body doesn't
  surface `e2e_id` as plain text — e.g. `body: {:bytes, ...}`,
  which OTLP→Loki encodes as base64 — filter on the
  structured-metadata attribute instead (`query/2`).
  """

  @doc """
  Loki query URL for a line-substring filter — the canonical
  e2e selector for tests whose body carries `e2e_id` as plain
  text. The `{service_name=~".+"}` stream selector is purely
  a LogQL requirement (every query must carry at least one
  stream matcher) and accepts any service name.
  """
  @spec query(e2e_id :: String.t()) :: String.t()
  def query(e2e_id), do: query_logql(~s({service_name=~".+"} |= "#{e2e_id}"))

  @doc """
  Loki query URL for a structured-metadata filter on an OTLP
  attribute. Use this when the body doesn't surface the value
  as plain text in the rendered line — e.g. bytes bodies that
  OTLP→Loki encodes as base64. Backticks let LogQL accept
  attribute keys with dots (`e2e.id` → `` `e2e.id` ``).
  """
  @spec query(attribute_key :: String.t(), attribute_value :: String.t()) :: String.t()
  def query(attribute_key, attribute_value) do
    query_logql(~s({service_name=~".+"} | `#{attribute_key}` = "#{attribute_value}"))
  end

  @doc """
  Loki query URL for a raw LogQL expression. Escape hatch for
  selectors the convenience builders don't cover.
  """
  @spec query_logql(logql :: String.t()) :: String.t()
  def query_logql(logql) do
    now = System.system_time(:nanosecond)
    start = now - 60 * 1_000_000_000

    %URI{
      scheme: "http",
      host: "localhost",
      port: 3100,
      path: "/loki/api/v1/query_range",
      query:
        URI.encode_query(
          query: logql,
          start: start,
          end: now,
          limit: 10
        )
    }
    |> URI.to_string()
  end
end
