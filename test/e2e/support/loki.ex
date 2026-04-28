defmodule Otel.E2E.Loki do
  @moduledoc """
  Loki (log backend) query helpers.
  """

  @base "http://localhost:3100"

  @doc """
  Polls Loki's `/loki/api/v1/query_range` for log lines containing
  `e2e_id`.

  The actual match is the `|= "<e2e_id>"` line filter; the
  `{service_name=~".+"}` stream selector is purely a LogQL
  requirement (every query must carry at least one stream matcher)
  and accepts any service name.
  """
  @spec find(e2e_id :: String.t(), opts :: keyword()) :: Otel.E2E.Polling.result()
  def find(e2e_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)

    Otel.E2E.Polling.until(timeout, fn ->
      query = ~s({service_name=~".+"} |= "#{e2e_id}")
      now = System.system_time(:nanosecond)
      start = now - 60 * 1_000_000_000

      url =
        "#{@base}/loki/api/v1/query_range" <>
          "?query=#{URI.encode_www_form(query)}" <>
          "&start=#{start}" <>
          "&end=#{now}" <>
          "&limit=10"

      with {:ok, body} <- Otel.E2E.HTTP.get(url),
           true <- String.contains?(body, e2e_id) do
        {:ok, body}
      else
        _ -> :retry
      end
    end)
  end
end
