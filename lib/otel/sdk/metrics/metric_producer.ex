defmodule Otel.SDK.Metrics.MetricProducer do
  @moduledoc """
  Behaviour for bridging third-party metric sources into the
  OpenTelemetry metrics pipeline.

  MetricProducers are registered with a MetricReader. During
  collection, the reader calls `produce/1` to retrieve external
  metrics alongside SDK-generated ones.
  """

  @callback produce(config :: term()) ::
              {:ok, [Otel.SDK.Metrics.MetricReader.metric()]} | {:error, term()}
end
