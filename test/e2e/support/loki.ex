defmodule Otel.E2E.Loki do
  @moduledoc """
  Loki (log backend) URL builders.
  """

  @doc """
  Loki `/loki/api/v1/query_range` URL for the given e2e_id.

  The actual match is the `|= "<e2e_id>"` line filter; the
  `{service_name=~".+"}` stream selector is purely a LogQL
  requirement (every query must carry at least one stream matcher)
  and accepts any service name.
  """
  @spec query(e2e_id :: String.t()) :: String.t()
  def query(e2e_id) do
    now = System.system_time(:nanosecond)
    start = now - 60 * 1_000_000_000

    %URI{
      scheme: "http",
      host: "localhost",
      port: 3100,
      path: "/loki/api/v1/query_range",
      query:
        URI.encode_query(
          query: ~s({service_name=~".+"} |= "#{e2e_id}"),
          start: start,
          end: now,
          limit: 10
        )
    }
    |> URI.to_string()
  end
end
