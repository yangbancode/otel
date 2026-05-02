defmodule Otel.Metrics.MeterProvider do
  @moduledoc """
  MeterProvider — minikube hardcoded.

  Issues `%Otel.Metrics.Meter{}` structs and forwards
  `shutdown/1` / `force_flush/1` to the single hardcoded
  `Otel.Metrics.MetricReader.PeriodicExporting` (60s/30s
  interval/timeout). Configuration (`resource`,
  `exemplar_filter`) is loaded once at boot via `init/0` and
  stored in `:persistent_term` along with the named ETS
  tables that hold metrics state.

  Not a GenServer — `init/0` creates the named ETS tables and
  seeds `:persistent_term`; the tables are owned by the
  caller process (the SDK Application controller in
  production, or the test process in tests).

  ## Public API

  | Function | Role |
  |---|---|
  | `init/0` | **SDK** (boot hook) — create ETS, seed `:persistent_term` |
  | `get_meter/1` | **Application** (OTel API MUST) — Get a Meter |
  | `shutdown/1` | **Application** (OTel API MUST) — Shutdown |
  | `force_flush/1` | **Application** (OTel API MUST) — ForceFlush |
  | `resource/0`, `config/0` | **Application** (introspection) |
  | `shut_down?/0` | **SDK** — internal flag for instrument `enabled?` |
  | `delete_storage/0` | **SDK** (test cleanup) — drop ETS tables |

  ## References

  - OTel Metrics SDK §MeterProvider: `opentelemetry-specification/specification/metrics/sdk.md` L43-L155
  """

  require Logger

  @persistent_key {__MODULE__, :state}

  @ets_tables [
    :otel_instruments,
    :otel_streams,
    :otel_metrics,
    :otel_callbacks,
    :otel_exemplars,
    :otel_observed_attrs
  ]

  @typedoc "Internal provider state held in `:persistent_term`."
  @type state :: %{
          resource: Otel.Resource.t(),
          exemplar_filter: Otel.Metrics.Exemplar.Filter.t(),
          base_meter_config: map(),
          reader_meter_config: map(),
          reader_id: reference() | nil,
          shut_down: boolean()
        }

  @doc """
  **SDK** (boot hook) — Called once from
  `Otel.SDK.Application.start/2` (or from `Otel.TestSupport`
  for tests) to create the named ETS tables and seed the
  `:persistent_term` slot from `Otel.SDK.Config.metrics/0`.

  Idempotent: a second call replaces the persistent_term slot
  and reuses the existing ETS tables (or creates them if
  missing).
  """
  @spec init() :: :ok
  def init do
    config = Otel.SDK.Config.metrics()
    ensure_tables!()

    reader_id = make_ref()

    base_meter_config = %{
      resource: config.resource,
      instruments_tab: :otel_instruments,
      streams_tab: :otel_streams,
      metrics_tab: :otel_metrics,
      callbacks_tab: :otel_callbacks,
      exemplars_tab: :otel_exemplars,
      observed_attrs_tab: :otel_observed_attrs,
      exemplar_filter: config.exemplar_filter
    }

    reader_meter_config =
      base_meter_config
      |> Map.put(:reader_id, reader_id)
      |> Map.put(:temporality_mapping, Otel.Metrics.Instrument.default_temporality_mapping())

    :persistent_term.put(@persistent_key, %{
      resource: config.resource,
      exemplar_filter: config.exemplar_filter,
      base_meter_config: base_meter_config,
      reader_meter_config: reader_meter_config,
      reader_id: reader_id,
      shut_down: false
    })

    :ok
  end

  @doc """
  **SDK** (test cleanup) — Drops all named ETS tables and the
  persistent_term slot. Called from `Otel.TestSupport.stop_all/0`
  so each test starts from a clean slate.
  """
  @spec delete_storage() :: :ok
  def delete_storage do
    Enum.each(@ets_tables, fn name ->
      case :ets.whereis(name) do
        :undefined -> :ok
        _tid -> :ets.delete(name)
      end
    end)

    :persistent_term.erase(@persistent_key)
    :ok
  end

  @doc """
  **Application** (OTel API MUST) — Get a Meter
  (`metrics/api.md` §Get a Meter).

  Returns a configured `%Otel.Metrics.Meter{}` struct stamped
  with the boot-time meter config and the caller's
  instrumentation scope. After `shutdown/1`, returns an empty
  Meter (no instruments, no readers).
  """
  @spec get_meter(instrumentation_scope :: Otel.InstrumentationScope.t()) ::
          Otel.Metrics.Meter.t()
  def get_meter(%Otel.InstrumentationScope{} = instrumentation_scope) do
    state = state()

    if state.shut_down do
      %Otel.Metrics.Meter{}
    else
      warn_invalid_scope_name(instrumentation_scope)

      reader_meter_config = state.reader_meter_config
      reader_opts = %{temporality_mapping: reader_meter_config.temporality_mapping}

      meter_config =
        Map.merge(state.base_meter_config, %{
          scope: instrumentation_scope,
          reader_configs: [{state.reader_id, reader_opts}]
        })

      %Otel.Metrics.Meter{config: meter_config}
    end
  end

  @doc """
  **Application** (OTel API MUST) — Shutdown
  (`metrics/sdk.md` §Shutdown).

  Sets the shut-down flag and forwards to
  `Otel.Metrics.MetricReader.PeriodicExporting.shutdown/0`.
  """
  @spec shutdown(timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(_timeout \\ 5_000) do
    case :persistent_term.get(@persistent_key, nil) do
      nil ->
        :ok

      %{shut_down: true} ->
        {:error, :already_shutdown}

      state ->
        :persistent_term.put(@persistent_key, %{state | shut_down: true})
        Otel.Metrics.MetricReader.PeriodicExporting.shutdown()
    end
  end

  @doc """
  **Application** (OTel API MUST) — ForceFlush
  (`metrics/sdk.md` §ForceFlush).

  Returns `:ok` when the SDK isn't booted (no persistent_term
  state) — matches the graceful "facade is always callable"
  contract. Returns `{:error, :already_shutdown}` only after an
  explicit `shutdown/1`.
  """
  @spec force_flush(timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(_timeout \\ 5_000) do
    case :persistent_term.get(@persistent_key, nil) do
      nil -> :ok
      %{shut_down: true} -> {:error, :already_shutdown}
      _ -> Otel.Metrics.MetricReader.PeriodicExporting.force_flush()
    end
  end

  @doc """
  **Application** (introspection) — Returns the resource
  associated with this provider, or `Otel.Resource.default/0`
  when the SDK isn't booted.
  """
  @spec resource() :: Otel.Resource.t()
  def resource, do: state().resource

  @doc """
  **Application** (introspection) — Returns the persistent_term
  state, or an empty map when the SDK isn't booted.
  """
  @spec config() :: state() | %{}
  def config, do: :persistent_term.get(@persistent_key, %{})

  @doc """
  **SDK** — Returns `true` when shutdown has been invoked.
  """
  @spec shut_down?() :: boolean()
  def shut_down? do
    state = :persistent_term.get(@persistent_key, nil)
    state == nil or state.shut_down
  end

  @doc """
  **SDK** — Returns the reader_meter_config seeded by `init/0`.
  Used by `Otel.Metrics.MetricReader.PeriodicExporting.init/1`
  to read the named ETS tables and reader_id.
  """
  @spec reader_meter_config() :: map() | nil
  def reader_meter_config do
    case :persistent_term.get(@persistent_key, nil) do
      nil -> nil
      state -> state.reader_meter_config
    end
  end

  # --- Private ---

  @spec state() :: state()
  defp state, do: :persistent_term.get(@persistent_key, default_state())

  @spec default_state() :: state()
  defp default_state do
    %{
      resource: Otel.Resource.default(),
      exemplar_filter: :trace_based,
      base_meter_config: %{},
      reader_meter_config: %{},
      reader_id: nil,
      shut_down: false
    }
  end

  @spec ensure_tables!() :: :ok
  defp ensure_tables! do
    table_specs = [
      {:otel_instruments, [:set, :public, :named_table]},
      {:otel_streams, [:bag, :public, :named_table]},
      {:otel_metrics, [:set, :public, :named_table]},
      {:otel_callbacks, [:bag, :public, :named_table]},
      {:otel_exemplars, [:set, :public, :named_table]},
      {:otel_observed_attrs, [:set, :public, :named_table]}
    ]

    Enum.each(table_specs, fn {name, opts} ->
      case :ets.whereis(name) do
        :undefined ->
          :ets.new(name, opts ++ [read_concurrency: true, write_concurrency: true])
          :ok

        _tid ->
          :ok
      end
    end)

    :ok
  end

  @spec warn_invalid_scope_name(scope :: Otel.InstrumentationScope.t()) :: :ok
  defp warn_invalid_scope_name(%Otel.InstrumentationScope{name: ""}) do
    Logger.warning(
      "Otel.Metrics.MeterProvider: invalid Meter name (empty string) — returning a working Meter as fallback"
    )

    :ok
  end

  defp warn_invalid_scope_name(_scope), do: :ok
end
