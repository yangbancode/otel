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
  OTLP→Loki encodes as base64.

  The OTel Collector's Loki exporter sanitises attribute keys
  the same way Prometheus does — `.` becomes `_` — so
  callers pass the OTel key (e.g. `"e2e.id"`) and this helper
  converts it to the LogQL identifier (`e2e_id`).
  """
  @spec query(attribute_key :: String.t(), attribute_value :: String.t()) :: String.t()
  def query(attribute_key, attribute_value) do
    sanitized = String.replace(attribute_key, ".", "_")
    query_logql(~s({service_name=~".+"} | #{sanitized}="#{attribute_value}"))
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

  @doc """
  Flattens every `[timestamp, line]` pair across all streams in
  a Loki query result list into the raw log lines (strings).
  Useful when a test wants to assert on rendered body content
  regardless of which stream Loki bucketed it under.
  """
  @spec lines(results :: [map()]) :: [String.t()]
  def lines(results) do
    Enum.flat_map(results, fn %{"values" => values} ->
      Enum.map(values, fn [_ts, line] -> line end)
    end)
  end

  @doc """
  Returns the stream labels for the first result entry. Use
  when a test produced a single stream and wants to assert on
  one of its labels (severity_text, custom attribute, etc.).
  """
  @spec labels(results :: [map()]) :: %{String.t() => String.t()}
  def labels([%{"stream" => labels} | _]), do: labels
  def labels(_), do: %{}

  @doc """
  Looks up a single OTLP attribute on a Loki entry — Loki
  surfaces them as either stream labels or structured metadata
  on each `[ts, line, metadata]` triple, depending on otel-lgtm
  config. This walks both shapes and returns the first value
  (atom-keyed dot-style OTel keys are sanitised the same way
  the collector sanitises them: `.` → `_`).
  """
  @spec attribute(results :: [map()], key :: String.t()) :: String.t() | nil
  def attribute(results, key) do
    sanitized = String.replace(key, ".", "_")

    Enum.find_value(results, fn entry ->
      stream_value(entry, sanitized) || metadata_value(entry, sanitized)
    end)
  end

  defp stream_value(%{"stream" => labels}, key), do: Map.get(labels, key)
  defp stream_value(_, _), do: nil

  defp metadata_value(%{"values" => values}, key) do
    Enum.find_value(values, fn
      [_ts, _line, meta] when is_map(meta) -> Map.get(meta, key)
      _ -> nil
    end)
  end

  defp metadata_value(_, _), do: nil
end
