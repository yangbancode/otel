defmodule Otel.E2E.Emitter do
  @moduledoc """
  Shared scope + flush helpers for e2e tests.

  Telemetry emission itself uses the SDK API directly in each
  test — `with_span/4`, `Logger.emit/2`, `Counter.add/3`, etc. —
  so the test reads as a literal walkthrough of the public API.
  This module exposes only the bits that are awkward to inline:
  the shared `InstrumentationScope` and the three pillar
  `force_flush` calls.
  """

  @scope %Otel.API.InstrumentationScope{name: "e2e", version: "0.1.0"}

  @doc "InstrumentationScope used by every e2e test."
  def scope, do: @scope

  @doc "Force-flushes the SDK TracerProvider."
  def flush_traces, do: Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)

  @doc "Force-flushes the SDK LoggerProvider."
  def flush_logs, do: Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)

  @doc "Force-flushes the SDK MeterProvider."
  def flush_metrics,
    do: Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
end
