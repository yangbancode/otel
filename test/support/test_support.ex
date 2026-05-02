defmodule Otel.TestSupport do
  @moduledoc """
  Test-only helpers for booting the SDK with custom config.

  After the Phase-2 cleanup the three providers are pure-function
  modules — there is no `Otel.Trace.TracerProvider` GenServer to
  swap out. Custom test config is delivered by:

  1. Setting `Application.put_env(:otel, ...)` to override
     `Otel.SDK.Config.{trace,metrics,logs}/0` outputs.
  2. Re-seeding `:persistent_term` via `Provider.init/0`.
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
  | `:trace` | `:processors`, `:span_limits` |
  | `:metrics` | `:readers` |
  | `:logs` | `:processors`, `:log_record_limits` |

  `:processors` / `:readers` are lists of `{module, config}`
  tuples. The first entry's module is started under the
  hardcoded name and receives all dispatch. Multi-processor
  test scenarios are no longer supported (minikube hardcodes
  one).
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @trace_keys [:processors, :span_limits, :resource]
  @metrics_keys [:readers, :exemplar_filter]
  @logs_keys [:processors, :log_record_limits, :resource]

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

    # 1. Seed persistent_term for all three providers (resource,
    # span_limits, exemplar_filter, log_record_limits, ETS).
    Otel.Trace.TracerProvider.init()
    Otel.Metrics.MeterProvider.init()
    Otel.Logs.LoggerProvider.init()

    # 2. Apply test-only overrides on top of the seeded state.
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
    :persistent_term.erase({Otel.Trace.TracerProvider, :state})
    :persistent_term.erase({Otel.Logs.LoggerProvider, :state})

    :ok
  end

  # --- Trace overrides ---

  @spec apply_trace_overrides(overrides :: keyword()) :: :ok
  defp apply_trace_overrides(overrides) do
    state = :persistent_term.get({Otel.Trace.TracerProvider, :state})

    state =
      Enum.reduce(overrides, state, fn
        {:span_limits, limits}, acc -> %{acc | span_limits: limits}
        {:resource, resource}, acc -> %{acc | resource: resource}
        {:processors, _}, acc -> acc
      end)

    :persistent_term.put({Otel.Trace.TracerProvider, :state}, state)
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
    state = :persistent_term.get({Otel.Logs.LoggerProvider, :state})

    state =
      Enum.reduce(overrides, state, fn
        {:log_record_limits, limits}, acc -> %{acc | log_record_limits: limits}
        {:resource, resource}, acc -> %{acc | resource: resource}
        {:processors, _}, acc -> acc
      end)

    :persistent_term.put({Otel.Logs.LoggerProvider, :state}, state)
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
    state_key = {Otel.Metrics.MeterProvider, :state}
    state = :persistent_term.get(state_key)

    state =
      Enum.reduce(overrides, state, fn
        {:exemplar_filter, filter}, acc ->
          %{
            acc
            | exemplar_filter: filter,
              base_meter_config: %{acc.base_meter_config | exemplar_filter: filter},
              reader_meter_config: %{acc.reader_meter_config | exemplar_filter: filter}
          }

        {:readers, _}, acc ->
          acc
      end)

    :persistent_term.put(state_key, state)
    :ok
  end

  @spec start_metrics_reader(overrides :: keyword()) :: :ok
  defp start_metrics_reader(overrides) do
    case Keyword.get(overrides, :readers) do
      nil ->
        start_orphan!(Otel.Metrics.MetricReader.PeriodicExporting, %{})

      [] ->
        # No reader is running — patch MeterProvider's persistent_term
        # so streams created via `get_meter` carry `reader_id: nil`.
        # Tests that just inspect `MetricReader.collect/1` directly
        # rely on this nil-vs-nil match.
        state_key = {Otel.Metrics.MeterProvider, :state}
        state = :persistent_term.get(state_key)

        :persistent_term.put(state_key, %{
          state
          | reader_id: nil,
            reader_meter_config: %{state.reader_meter_config | reader_id: nil}
        })

      [{module, config}] ->
        # Reader's init expects meter_config — supply it from
        # MeterProvider's persistent_term.
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
