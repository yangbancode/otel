defmodule Otel.E2E.Emitter do
  @moduledoc """
  Shared setup + flush helpers for e2e tests against the local
  Grafana LGTM stack.

  Telemetry emission itself uses the SDK API directly in each
  test — `with_span/4`, `Logger.emit/2`, `Counter.add/3`, etc. —
  so the test reads as a literal walkthrough of the public API.

  This module exposes only the bits that genuinely need wrapping:
  the boot-time `OTEL_SERVICE_NAME` injection (requires
  `:otel` restart), the shared `InstrumentationScope`, and the
  three pillar `force_flush` calls.
  """

  @scope %Otel.API.InstrumentationScope{name: "e2e", version: "0.1.0"}

  @doc "InstrumentationScope used by every e2e test."
  def scope, do: @scope

  @doc """
  Restarts `:otel` with `OTEL_SERVICE_NAME=name` so the resource
  carries a recognisable `service.name`. Call from `setup_all`.
  """
  @spec setup_service_name(name :: String.t()) :: :ok
  def setup_service_name(name) do
    Application.stop(:otel)
    System.put_env("OTEL_SERVICE_NAME", name)
    {:ok, _} = Application.ensure_all_started(:otel)
    :ok
  end

  @doc "Force-flushes the SDK TracerProvider."
  def flush_traces, do: Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)

  @doc "Force-flushes the SDK LoggerProvider."
  def flush_logs, do: Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)

  @doc "Force-flushes the SDK MeterProvider."
  def flush_metrics,
    do: Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
end
