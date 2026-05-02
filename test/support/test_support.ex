defmodule Otel.TestSupport do
  @moduledoc """
  Test-only helpers for spinning up isolated provider GenServers
  with custom config.

  After the minikube config cleanup the per-pillar Application env
  override path was removed — production users have **no**
  configuration knob for `:processors` / `:readers` /
  `:span_limits` / `:exemplar_filter` / `:log_record_limits` /
  `:retry_opts`. Tests that exercise those code paths therefore
  bypass `Otel.SDK.Application` entirely: stop `:otel`, start each
  provider directly with the test's custom config (or spec
  defaults), and let `on_exit` restart the SDK back to defaults.

  ## Usage

      setup do
        Otel.TestSupport.restart_with(
          trace: [span_limits: %Otel.Trace.SpanLimits{attribute_count_limit: 2}]
        )
      end

  All three pillars (`:trace`, `:metrics`, `:logs`) are always
  started so cross-cutting tests (e.g. `Otel.E2E.Case.flush/0`)
  can call `force_flush` on any provider without race. Pass only
  the pillars whose defaults you want to override; everything
  else uses the same hardcoded values that
  `Otel.SDK.Config.{trace,metrics,logs}/0` produce.

  ## Pillar override keys

  | Pillar | Keys |
  |---|---|
  | `:trace` | `:resource`, `:processors`, `:span_limits` |
  | `:metrics` | `:resource`, `:readers`, `:exemplar_filter` |
  | `:logs` | `:resource`, `:processors`, `:log_record_limits` |

  Unknown keys raise — silent pass-through used to mask test bugs
  (the old `restart_sdk(trace: [processor: :batch, exporter: ...])`
  pattern was a no-op because `:processor` / `:exporter` were never
  read by `Otel.SDK.Config.trace/0`).
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @trace_keys [:resource, :processors, :span_limits]
  @metrics_keys [:resource, :readers, :exemplar_filter]
  @logs_keys [:resource, :processors, :log_record_limits]

  @doc """
  Stops `:otel`, starts the three providers with the merged
  config, schedules an `on_exit` that restarts the SDK back to
  defaults.

  Each pillar key is optional; when provided, the keyword list is
  validated and merged on top of the spec defaults from
  `Otel.SDK.Config.{trace,metrics,logs}/0`.
  """
  @spec restart_with(env :: keyword()) :: :ok
  def restart_with(env \\ []) do
    trace_overrides = Keyword.get(env, :trace, [])
    metrics_overrides = Keyword.get(env, :metrics, [])
    logs_overrides = Keyword.get(env, :logs, [])

    validate_keys!(:trace, trace_overrides, @trace_keys)
    validate_keys!(:metrics, metrics_overrides, @metrics_keys)
    validate_keys!(:logs, logs_overrides, @logs_keys)

    stop_all()

    start_orphan!(Otel.Trace.SpanStorage, [])
    start_orphan!(Otel.Trace.TracerProvider, trace_config(trace_overrides))
    start_orphan!(Otel.Metrics.MeterProvider, metrics_config(metrics_overrides))
    start_orphan!(Otel.Logs.LoggerProvider, logs_config(logs_overrides))

    on_exit(fn ->
      stop_all()
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  # Starts a provider GenServer **unlinked** and **with no registered
  # parent**. We can't use the public `start_link/1` because it both
  # links the caller and registers the test process as the gen_server
  # parent — under that registration, OTP routes any
  # `{:EXIT, test_pid, _}` message straight to terminate (regardless
  # of `Process.flag(:trap_exit, true)`), which breaks tests that
  # exercise the EXIT-trap path by `send/2`-ing simulated exits.
  #
  # `GenServer.start/3` skips both the link and the parent
  # registration, so the provider is fully decoupled from the test
  # process — exactly what we want for isolated test setup.
  @spec start_orphan!(module :: module(), init_arg :: term()) :: pid()
  defp start_orphan!(module, init_arg) do
    {:ok, pid} = GenServer.start(module, init_arg, name: module)
    pid
  end

  @doc """
  Stops every provider GenServer (whether started by
  `Otel.SDK.Application` or by `restart_with/1`) and the
  `Otel.Trace.SpanStorage` ETS owner.

  Use in tests that need to exercise "what happens when no
  provider is running" behaviour (e.g. facades returning safe
  defaults). The next `restart_with/1` call — or the on_exit
  scheduled by the previous `restart_with/1` — will bring the
  SDK back up.
  """
  @spec stop_all() :: :ok
  def stop_all do
    Application.stop(:otel)

    Enum.each(
      [
        Otel.Trace.TracerProvider,
        Otel.Metrics.MeterProvider,
        Otel.Logs.LoggerProvider,
        Otel.Trace.SpanStorage
      ],
      &stop_named/1
    )

    :ok
  end

  # Best-effort stop. Providers were `start_link`'d from the calling
  # test process so they're linked to it — sending an exit signal
  # would kill the test too. Unlink first, then Process.exit/2 with
  # `:kill` (un-trappable) and wait for the DOWN. `GenServer.stop/3`
  # is unsafe here because some tests intentionally leave the
  # Provider in a state where its `terminate` callback hangs.
  @spec stop_named(name :: atom()) :: :ok
  defp stop_named(name) do
    case GenServer.whereis(name) do
      nil ->
        :ok

      pid ->
        Process.unlink(pid)
        ref = Process.monitor(pid)
        Process.exit(pid, :kill)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          1_000 -> :ok
        end
    end
  end

  @spec trace_config(overrides :: keyword()) :: map()
  defp trace_config(overrides) do
    base = Otel.SDK.Config.trace()

    %{
      resource: Keyword.get(overrides, :resource, base.resource),
      processors: Keyword.get(overrides, :processors, base.processors),
      span_limits: Keyword.get(overrides, :span_limits, base.span_limits)
    }
  end

  @spec metrics_config(overrides :: keyword()) :: map()
  defp metrics_config(overrides) do
    base = Otel.SDK.Config.metrics()

    %{
      resource: Keyword.get(overrides, :resource, base.resource),
      readers: Keyword.get(overrides, :readers, base.readers),
      exemplar_filter: Keyword.get(overrides, :exemplar_filter, base.exemplar_filter)
    }
  end

  @spec logs_config(overrides :: keyword()) :: map()
  defp logs_config(overrides) do
    base = Otel.SDK.Config.logs()

    %{
      resource: Keyword.get(overrides, :resource, base.resource),
      processors: Keyword.get(overrides, :processors, base.processors),
      log_record_limits: Keyword.get(overrides, :log_record_limits, base.log_record_limits)
    }
  end

  @spec validate_keys!(pillar :: atom(), overrides :: keyword(), allowed :: [atom()]) :: :ok
  defp validate_keys!(pillar, overrides, allowed) do
    case Keyword.keys(overrides) -- allowed do
      [] ->
        :ok

      bad ->
        raise ArgumentError,
              "Otel.TestSupport.restart_with/1: unknown #{pillar} keys #{inspect(bad)} " <>
                "(allowed: #{inspect(allowed)})"
    end
  end
end
