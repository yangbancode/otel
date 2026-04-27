defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    Otel.API.Trace.Span.set_module(Otel.SDK.Trace.Span)

    children =
      if Otel.SDK.Config.disabled?() do
        # Spec L113-L114 — `OTEL_SDK_DISABLED=true` means the SDK is
        # no-op for all signals. We register no providers, so the API
        # facades fall through to their built-in noop implementations.
        []
      else
        [
          Otel.SDK.Trace.SpanStorage,
          {Otel.SDK.Trace.TracerProvider,
           [config: Otel.SDK.Config.trace(), name: Otel.SDK.Trace.TracerProvider]},
          {Otel.SDK.Metrics.MeterProvider,
           [config: Otel.SDK.Config.metrics(), name: Otel.SDK.Metrics.MeterProvider]},
          {Otel.SDK.Logs.LoggerProvider,
           [config: Otel.SDK.Config.logs(), name: Otel.SDK.Logs.LoggerProvider]}
        ]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
