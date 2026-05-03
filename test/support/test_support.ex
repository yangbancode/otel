defmodule Otel.TestSupport do
  @moduledoc """
  Test-only helpers for booting the SDK with custom config.

  Trace and Logs have no provider modules anymore — both
  `Otel.Trace.TracerProvider` and `Otel.Logs.LoggerProvider`
  were dissolved into their facades (`Otel.Trace`, `Otel.Logs`).
  Metrics still has `MeterProvider`, whose `init/0` is the
  only boot-time work (creating the named ETS tables).
  Custom test config is delivered by:

  1. Setting `Application.put_env(:otel, ...)` to override the
     user-facing `:resource` / `:exporter` keys.
  2. `Otel.Metrics.MeterProvider.init/0` to (re)create the named
     ETS tables.
  3. Starting the supervised processor children
     (`SpanStorage`, `SpanProcessor`, `PeriodicExporting`,
     `LogRecordProcessor`) — or substitutes thereof — so
     dispatch from `Span`/`Logger`/`Meter` lands somewhere
     observable.

  Tests inject custom processors by registering a different
  GenServer under the hardcoded names
  (`Otel.Trace.SpanProcessor`, `Otel.Logs.LogRecordProcessor`,
  `Otel.Metrics.MetricReader.PeriodicExporting`). The Span /
  Logger dispatch sites use `send/2` (or `:gen_statem.cast/2`)
  to those names, so any compatible GenServer registered there
  receives the messages.

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
  | `:logs` | `:processors` |

  Tests that need custom span/log-record limits, exemplar
  filter, or resource construct the relevant struct (or the
  meter `config` map) directly with the desired values —
  none of those flow through `Otel.TestSupport` overrides
  anymore. Resource changes propagate through
  `Application.put_env(:otel, :resource, %{...})`.

  `:processors` / `:readers` are lists of `{module, config}`
  tuples. The first entry's module is started under the
  hardcoded name and receives all dispatch. Multi-processor
  test scenarios are no longer supported (minikube hardcodes
  one).
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @trace_keys [:processors]
  @metrics_keys [:readers]
  @logs_keys [:processors]

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

    # 1. Create the named ETS tables. `Otel.Trace` / `Otel.Logs`
    # hold no boot-time state — `:resource` is read via
    # `Otel.Resource.from_app_env/0` on demand.
    Otel.Metrics.MeterProvider.init()

    # 2. Apply test-only overrides via `Application.put_env/3`.
    apply_trace_overrides(trace_overrides)
    apply_metrics_overrides(metrics_overrides)
    apply_logs_overrides(logs_overrides)

    # 3. Start the supervised processor children (or substitutes).
    start_orphan!(Otel.Trace.SpanStorage, [])
    start_trace_processor(trace_overrides)
    start_metrics_reader(metrics_overrides)
    start_logs_processor(logs_overrides)

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
        Otel.Trace.SpanProcessor,
        Otel.Metrics.MetricReader.PeriodicExporting,
        Otel.Logs.LogRecordProcessor,
        Otel.Trace.SpanStorage
      ],
      &stop_named/1
    )

    Otel.Metrics.MeterProvider.delete_storage()
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
        # Default: hardcoded BatchSpanProcessor reading from SDK config.
        start_orphan!(Otel.Trace.SpanProcessor, %{})

      [] ->
        # Empty list — dispatch goes nowhere; tests that don't care
        # about processor side effects.
        :ok

      [{module, config}] ->
        # Single substitute processor under the hardcoded name.
        start_orphan_named!(module, config, Otel.Trace.SpanProcessor)

      _ ->
        raise ArgumentError,
              "minikube only supports a single SpanProcessor; got #{inspect(overrides[:processors])}"
    end

    :ok
  end

  # --- Logs overrides ---

  @spec apply_logs_overrides(overrides :: keyword()) :: :ok
  defp apply_logs_overrides(overrides) do
    Enum.each(overrides, fn
      {:processors, _} -> :ok
    end)

    :ok
  end

  @spec start_logs_processor(overrides :: keyword()) :: :ok
  defp start_logs_processor(overrides) do
    case Keyword.get(overrides, :processors) do
      nil ->
        start_orphan!(Otel.Logs.LogRecordProcessor, %{})

      [] ->
        :ok

      [{module, config}] ->
        start_orphan_named!(module, config, Otel.Logs.LogRecordProcessor)

      _ ->
        raise ArgumentError, "minikube only supports a single LogRecordProcessor"
    end

    :ok
  end

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
        start_orphan!(Otel.Metrics.MetricReader.PeriodicExporting, %{})

      [] ->
        # No reader is running — tests that just inspect
        # `MetricReader.collect/1` directly do so by passing the
        # config they want; the hardcoded `reader_id` in
        # `MeterProvider` matches whatever stream they registered.
        :ok

      [{module, config}] ->
        # Reader's init expects meter_config — supply it from
        # `MeterProvider.reader_meter_config/0` (computed inline).
        config =
          Map.put_new(config, :meter_config, Otel.Metrics.MeterProvider.reader_meter_config())

        start_orphan_named!(module, config, Otel.Metrics.MetricReader.PeriodicExporting)

      _ ->
        raise ArgumentError, "minikube only supports a single MetricReader"
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
