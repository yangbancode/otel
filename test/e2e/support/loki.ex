defmodule Otel.E2E.Loki do
  @moduledoc """
  Loki (log backend) query helpers.
  """

  @base "http://localhost:3100"

  @doc """
  Polls Loki's `/loki/api/v1/query_range` for log lines matching
  `service_name="<service>"` and containing `e2e_id`. Default
  service is `"e2e"` (set by `Otel.E2E.Emitter.setup_service_name/1`).
  """
  @spec find(e2e_id :: String.t(), opts :: keyword()) :: Otel.E2E.Polling.result()
  def find(e2e_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)
    service = Keyword.get(opts, :service, "e2e")

    Otel.E2E.Polling.until(timeout, fn ->
      query = ~s({service_name="#{service}"} |= "#{e2e_id}")
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
