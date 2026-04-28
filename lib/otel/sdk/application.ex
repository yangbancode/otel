defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    Otel.API.Trace.Span.set_module(Otel.SDK.Trace.Span)

    configs =
      if Otel.SDK.Config.disabled?() do
        # Spec L113-L114 — `OTEL_SDK_DISABLED=true` means the SDK is
        # no-op for all signals. Skip provider config build, but
        # still resolve the propagator (spec L113 — propagators are
        # NOT affected by SDK_DISABLED).
        nil
      else
        build_provider_configs()
      end

    # Spec L113 — `OTEL_SDK_DISABLED=true` does NOT disable
    # propagators. Install the global propagator unconditionally.
    # Prefer the declarative-config propagator when a config file
    # was loaded (it ran through the same Selector machinery, so
    # it's compatible); otherwise fall back to env-var/Mix Config.
    Otel.API.Propagator.TextMap.set_propagator(
      (configs && configs[:propagator]) || Otel.SDK.Config.propagator()
    )

    children =
      if configs == nil do
        []
      else
        [
          Otel.SDK.Trace.SpanStorage,
          {Otel.SDK.Trace.TracerProvider, [config: configs.trace]},
          {Otel.SDK.Metrics.MeterProvider, [config: configs.metrics]},
          {Otel.SDK.Logs.LoggerProvider, [config: configs.logs]}
        ]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end

  @spec build_provider_configs() :: %{trace: map(), metrics: map(), logs: map()}
  defp build_provider_configs do
    if Otel.Configuration.config_file_set?() do
      Otel.Configuration.load!()
    else
      %{
        trace: Otel.SDK.Config.trace(),
        metrics: Otel.SDK.Config.metrics(),
        logs: Otel.SDK.Config.logs()
      }
    end
  end
end
