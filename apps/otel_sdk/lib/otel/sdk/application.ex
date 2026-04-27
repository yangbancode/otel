defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  require Logger

  # `:otel_config` is an optional, runtime-detected dependency
  # (`Code.ensure_loaded?/1` below). Suppress the compile-time
  # undefined-function warning that would otherwise fire because
  # `otel_sdk` doesn't list `:otel_config` in its mix.exs deps.
  @compile {:no_warn_undefined, Otel.Config}

  @config_file_env_var "OTEL_CONFIG_FILE"

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
          {Otel.SDK.Trace.TracerProvider,
           [config: configs.trace, name: Otel.SDK.Trace.TracerProvider]},
          {Otel.SDK.Metrics.MeterProvider,
           [config: configs.metrics, name: Otel.SDK.Metrics.MeterProvider]},
          {Otel.SDK.Logs.LoggerProvider,
           [config: configs.logs, name: Otel.SDK.Logs.LoggerProvider]}
        ]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end

  # Routes to the declarative-config pipeline (`Otel.Config.load!/0`)
  # when `OTEL_CONFIG_FILE` is set AND the optional `:otel_config`
  # app is on the dep path. Falls back to the env-var path
  # (`Otel.SDK.Config`) otherwise. The `Code.ensure_loaded?/1` check
  # avoids a hard compile-time dep on `:otel_config` —
  # SDK-only users don't pay the YAML/JSON-Schema cost.
  @spec build_provider_configs() :: %{trace: map(), metrics: map(), logs: map()}
  defp build_provider_configs do
    cond do
      config_file_set?() and Code.ensure_loaded?(Otel.Config) ->
        # `Code.ensure_loaded?/1` above confirms the module is
        # available; the direct call is safe at runtime. The
        # `@compile {:no_warn_undefined, Otel.Config}` directive
        # at the top of this module silences the compile-time
        # warning that would otherwise fire for SDK-only builds
        # (no `:otel_config` in deps).
        Otel.Config.load!()

      config_file_set?() ->
        Logger.warning(
          "Otel.SDK.Application: #{@config_file_env_var} is set but :otel_config app " <>
            "is not loaded; declarative configuration is unavailable, falling back to " <>
            "OTEL_* env-var configuration. Add `{:otel_config, ...}` to your deps to enable."
        )

        env_var_configs()

      true ->
        env_var_configs()
    end
  end

  @spec config_file_set?() :: boolean()
  defp config_file_set? do
    case System.get_env(@config_file_env_var) do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  @spec env_var_configs() :: %{trace: map(), metrics: map(), logs: map()}
  defp env_var_configs do
    %{
      trace: Otel.SDK.Config.trace(),
      metrics: Otel.SDK.Config.metrics(),
      logs: Otel.SDK.Config.logs()
    }
  end
end
