defmodule Otel.SDK.Metrics.Aggregation.Drop do
  @moduledoc """
  Drop aggregation. Ignores all measurements.
  """

  @behaviour Otel.SDK.Metrics.Aggregation

  @impl true
  def aggregate(_metrics_tab, _key, _value, _opts), do: :ok

  @impl true
  def collect(_metrics_tab, _stream_key, _opts), do: []
end
