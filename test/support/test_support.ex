defmodule Otel.TestSupport do
  @moduledoc """
  Test-only helpers for booting the SDK with custom config.

  All three pillars (Trace/Logs/Metrics) have dissolved their
  Provider modules into the corresponding `Otel.Trace` /
  `Otel.Logs` / `Otel.Metrics` facades. Custom test config is
  delivered by:

  1. Setting `Application.put_env(:otel, ...)` to override the
     user-facing `:req_options` key, or `System.put_env(...)`
     to set `RELEASE_NAME` / `RELEASE_VSN` for resource attrs.
  2. Starting the supervised storage / exporter children
     (`SpanStorage`, `LogRecordStorage`, the two per-table
     `XxxStorage` GenServers for metrics, `SpanExporter`,
     `LogRecordExporter`, `MetricExporter`) — or
     substitutes thereof — so the ETS tables exist and
     dispatch from `Span` / `Logs.emit` / `Meter` lands
     somewhere observable.

  Trace / Metrics tests can substitute the *exporter* by
  registering a different GenServer under the hardcoded names
  (`Otel.Trace.SpanExporter`, `Otel.Metrics.MetricExporter`).
  Logs do not support exporter substitution because
  `Otel.Logs.Logger.emit/2` calls
  `Otel.Logs.LogRecordStorage.insert/1` directly (a
  module-level function, not a name-based message). Tests
  verify log behaviour by inspecting `LogRecordStorage` itself
  via `take/1` or `:ets.tab2list/1`.

  ## Usage

      setup do
        Otel.TestSupport.restart_with(
          logs: [processors: [{CapturingProcessor, %{test_pid: self()}}]]
        )
      end

  ## Pillar override keys

  | Pillar | Keys |
  |---|---|
  | `:trace` | `:processors` |
  | `:metrics` | `:readers` |
  | `:logs` | (none — inspect `LogRecordStorage` directly) |

  Tests that need custom span/log-record limits, exemplar
  filter, or resource construct the relevant struct (or the
  meter `config` map) directly with the desired values —
  none of those flow through `Otel.TestSupport` overrides
  anymore. Resource changes propagate through
  `System.put_env("RELEASE_NAME", "...")` /
  `System.put_env("RELEASE_VSN", "...")`.

  `:processors` / `:readers` are lists of `{module, config}`
  tuples. The first entry's module is started under the
  hardcoded name and receives all dispatch. Multi-processor
  test scenarios are no longer supported (minikube hardcodes
  one).
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @trace_keys [:processors]
  @metrics_keys [:readers]
  @logs_keys []

  @doc """
  Stops `:otel`, applies overrides, re-seeds providers and
  starts the supervised processor children. Schedules an
  `on_exit` that fully tears down the SDK.

  Pillars not mentioned default to standard SDK config — all
  three are always seeded so cross-cutting tests can call
  `force_flush` on any provider.
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

    # 1. Apply test-only overrides via `Application.put_env/3`.
    # `Otel.Trace` / `Otel.Logs` hold no boot-time state — the
    # SDK resource is read via `Otel.Resource.build/0` on demand.
    apply_trace_overrides(trace_overrides)
    apply_metrics_overrides(metrics_overrides)
    apply_logs_overrides(logs_overrides)

    # 2. Start the supervised storage / processor children. The two
    # per-table `XxxStorage` GenServers own the metrics ETS tables and
    # must start before `start_metrics_reader` (the exporter reads
    # `meter_config/0` on each tick / `force_flush`).
    start_orphan!(Otel.Trace.SpanStorage, [])
    start_orphan!(Otel.Logs.LogRecordStorage, [])
    start_orphan!(Otel.Metrics.InstrumentsStorage, [])
    start_orphan!(Otel.Metrics.MetricsStorage, [])
    start_trace_processor(trace_overrides)
    start_metrics_reader(metrics_overrides)
    start_orphan!(Otel.Logs.LogRecordExporter, [])

    on_exit(fn ->
      stop_all()
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  @doc """
  Tears down everything `restart_with/1` started — supervised
  processors, ETS storage tables, persistent_term slots — and
  stops `:otel`.

  Use in tests that need to assert facade behaviour when no
  Provider state exists.
  """
  @spec stop_all() :: :ok
  def stop_all do
    Application.stop(:otel)

    Enum.each(
      [
        Otel.Trace.SpanExporter,
        Otel.Logs.LogRecordExporter,
        Otel.Metrics.MetricExporter,
        Otel.Trace.SpanStorage,
        Otel.Logs.LogRecordStorage,
        Otel.Metrics.InstrumentsStorage,
        Otel.Metrics.MetricsStorage
      ],
      &stop_named/1
    )

    :ok
  end

  # --- Trace overrides ---

  @spec apply_trace_overrides(overrides :: keyword()) :: :ok
  defp apply_trace_overrides(overrides) do
    Enum.each(overrides, fn
      {:processors, _} -> :ok
    end)

    :ok
  end

  @spec start_trace_processor(overrides :: keyword()) :: :ok
  defp start_trace_processor(overrides) do
    case Keyword.get(overrides, :processors) do
      nil ->
        # Default: hardcoded SpanExporter reading from SDK config.
        start_orphan!(Otel.Trace.SpanExporter, [])

      [] ->
        # Empty list — dispatch goes nowhere; tests that don't care
        # about processor side effects.
        :ok

      [{module, config}] ->
        # Single substitute processor under the hardcoded name.
        start_orphan_named!(module, config, Otel.Trace.SpanExporter)

      _ ->
        raise ArgumentError,
              "minikube only supports a single SpanExporter; got #{inspect(overrides[:processors])}"
    end

    :ok
  end

  # --- Logs overrides ---
  #
  # No overrides — `Otel.Logs.Logger.emit/2` calls
  # `Otel.Logs.LogRecordStorage.insert/1` directly, which is a
  # module-level function that cannot be substituted by
  # registering a different process under the name. Tests
  # inspect the storage via `take/1` or `:ets.tab2list/1`.

  @spec apply_logs_overrides(overrides :: keyword()) :: :ok
  defp apply_logs_overrides(_overrides), do: :ok

  # --- Metrics overrides ---

  @spec apply_metrics_overrides(overrides :: keyword()) :: :ok
  defp apply_metrics_overrides(overrides) do
    Enum.each(overrides, fn
      {:readers, _} -> :ok
    end)

    :ok
  end

  @spec start_metrics_reader(overrides :: keyword()) :: :ok
  defp start_metrics_reader(overrides) do
    case Keyword.get(overrides, :readers) do
      nil ->
        start_orphan!(Otel.Metrics.MetricExporter, [])

      [] ->
        # No exporter is running — tests that just inspect
        # `Otel.Metrics.MetricExporter.collect/1` directly do so
        # by passing the config they want.
        :ok

      [{module, config}] ->
        start_orphan_named!(module, config, Otel.Metrics.MetricExporter)

      _ ->
        raise ArgumentError, "minikube only supports a single MetricExporter"
    end

    :ok
  end

  # --- Process control ---

  @spec start_orphan!(module :: module(), init_arg :: term()) :: pid()
  defp start_orphan!(module, init_arg) do
    {:ok, pid} = module.start_link(init_arg)
    Process.unlink(pid)
    pid
  end

  # When a test substitutes a custom GenServer under one of the
  # hardcoded processor names, we can't go through `start_link`
  # (which uses the substitute's own `name:` registration). Instead
  # use `:proc_lib.spawn_link` style — let the substitute call
  # `start_link` itself, then re-register under the hardcoded name.
  # Tests typically pass a module that registers itself under the
  # hardcoded name in its own `start_link`.
  @spec start_orphan_named!(module :: module(), config :: term(), name :: atom()) :: pid()
  defp start_orphan_named!(module, config, _name) do
    {:ok, pid} = module.start_link(config)
    Process.unlink(pid)
    pid
  end

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
