defmodule Otel.SDK.Metrics.MetricExporter do
  @moduledoc """
  Behaviour for push metric exporters.

  Exporters receive batches of collected metrics and transmit them
  to a backend. Export calls are serialized by the MetricReader.

  ## Concurrency

  Spec `metrics/sdk.md` L1883-L1884 (Status: Stable) —
  *"ForceFlush and Shutdown MUST be safe to be called
  concurrently."* `export/2` is called serially by the
  MetricReader (see moduledoc above) so the MUST is on
  `force_flush/1` and `shutdown/1` callbacks; implementations
  MUST handle a `force_flush` arriving while another
  `force_flush` (from a different caller) or `shutdown` is in
  progress.
  """

  @type state :: term()

  @callback init(config :: term()) :: {:ok, state()} | :ignore

  @callback export(
              metrics :: [Otel.SDK.Metrics.MetricReader.metric()],
              state :: state()
            ) :: :ok | :error

  @callback force_flush(state :: state()) :: :ok

  @callback shutdown(state :: state()) :: :ok
end
