defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) URL builders + a single attribute-lookup
  helper.

  Two-step retrieval: `search/1` returns trace IDs by tag, then
  `get_trace/1` fetches the full OTLP-shaped JSON for a single
  trace so tests can assert on span name / attributes / parent
  chain / events / status / kind / etc.
  """

  @port 3200

  @doc "Tempo `/api/search` URL — find traces by tag."
  @spec search(e2e_id :: String.t()) :: String.t()
  def search(e2e_id) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: @port,
      path: "/api/search",
      query: URI.encode_query(tags: "e2e.id=#{e2e_id}", limit: 32)
    }
    |> URI.to_string()
  end

  @doc "Tempo `/api/traces/{trace_id}` URL — full trace detail."
  @spec get_trace(trace_id :: String.t()) :: String.t()
  def get_trace(trace_id) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: @port,
      path: "/api/traces/#{trace_id}"
    }
    |> URI.to_string()
  end

  @doc """
  Looks up a single attribute on a span by key, decoding the
  OTLP/JSON `AnyValue` wrapper. Returns `nil` if absent.
  """
  @spec attribute(span :: map(), key :: String.t()) :: term() | nil
  def attribute(span, key) do
    case Enum.find(span["attributes"] || [], &(&1["key"] == key)) do
      nil -> nil
      %{"value" => v} -> any_value(v)
    end
  end

  defp any_value(%{"stringValue" => v}), do: v
  defp any_value(%{"intValue" => v}) when is_binary(v), do: String.to_integer(v)
  defp any_value(%{"intValue" => v}), do: v
  defp any_value(%{"doubleValue" => v}), do: v
  defp any_value(%{"boolValue" => v}), do: v
  defp any_value(%{"arrayValue" => %{"values" => vs}}), do: Enum.map(vs, &any_value/1)

  defp any_value(%{"kvlistValue" => %{"values" => kvs}}) do
    Map.new(kvs, fn %{"key" => k, "value" => v} -> {k, any_value(v)} end)
  end
end
