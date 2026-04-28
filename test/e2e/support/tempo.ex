defmodule Otel.E2E.Tempo do
  @moduledoc """
  Tempo (trace backend) URL builders.

  Two-step retrieval: `query/1` returns trace IDs by tag, then
  `trace/1` fetches the full OTLP-shaped JSON for a single trace
  so tests can assert on span name / attributes / parent chain /
  events / status / kind / etc.
  """

  @port 3200

  @doc "Tempo `/api/search` URL for the given e2e_id."
  @spec query(e2e_id :: String.t()) :: String.t()
  def query(e2e_id) do
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
  @spec trace(trace_id :: String.t()) :: String.t()
  def trace(trace_id) do
    %URI{
      scheme: "http",
      host: "localhost",
      port: @port,
      path: "/api/traces/#{trace_id}"
    }
    |> URI.to_string()
  end

  @doc """
  Flattens the OTLP-shaped trace JSON Tempo returns into a plain
  list of span maps, dropping `batches` / `scopeSpans` nesting.
  """
  @spec spans_of(trace :: map()) :: [map()]
  def spans_of(%{"batches" => batches}) do
    Enum.flat_map(batches, fn batch ->
      Enum.flat_map(batch["scopeSpans"] || [], &(&1["spans"] || []))
    end)
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

  @doc """
  Decodes an OTLP/JSON `AnyValue` wrapper into the underlying
  Elixir term. Tempo's JSON renders ints as strings (protobuf
  conventions), so int values are normalised back.
  """
  @spec any_value(value :: map()) :: term()
  def any_value(%{"stringValue" => v}), do: v
  def any_value(%{"intValue" => v}) when is_binary(v), do: String.to_integer(v)
  def any_value(%{"intValue" => v}), do: v
  def any_value(%{"doubleValue" => v}), do: v
  def any_value(%{"boolValue" => v}), do: v
  def any_value(%{"arrayValue" => %{"values" => vs}}), do: Enum.map(vs, &any_value/1)

  def any_value(%{"kvlistValue" => %{"values" => kvs}}) do
    Map.new(kvs, fn %{"key" => k, "value" => v} -> {k, any_value(v)} end)
  end
end
