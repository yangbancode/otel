defmodule Otel.E2E.Loki do
  @moduledoc """
  Loki (log backend) query helpers.
  """

  @base "http://localhost:3100"

  @doc """
  Polls Loki's `/loki/api/v1/query_range` until at least one log line
  matches.

  The actual match is the `|= "<e2e_id>"` line filter; the
  `{service_name=~".+"}` stream selector is purely a LogQL
  requirement (every query must carry at least one stream matcher)
  and accepts any service name.
  """
  @spec find(e2e_id :: String.t(), opts :: keyword()) :: Otel.E2E.HTTP.result()
  def find(e2e_id, opts \\ []) do
    query = ~s({service_name=~".+"} |= "#{e2e_id}")
    now = System.system_time(:nanosecond)
    start = now - 60 * 1_000_000_000

    url =
      "#{@base}/loki/api/v1/query_range" <>
        "?query=#{URI.encode_www_form(query)}" <>
        "&start=#{start}" <>
        "&end=#{now}" <>
        "&limit=10"

    Otel.E2E.HTTP.poll(
      url,
      fn
        %{"data" => %{"result" => [_ | _] = streams}} -> {:ok, streams}
        _ -> :empty
      end,
      opts
    )
  end
end
