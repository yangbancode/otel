defmodule Otel.Metrics.MeterProvider do
  @moduledoc """
  MeterProvider — minikube hardcoded.

  Issues `%Otel.Metrics.Meter{}` structs. Configuration
  (`resource`, `exemplar_filter`) is loaded once at boot via
  `init/0` and stored in `:persistent_term` along with the
  named ETS tables that hold metrics state.

  Not a GenServer — `init/0` creates the named ETS tables and
  seeds `:persistent_term`; the tables are owned by the
  caller process (the SDK Application controller in
  production, or the test process in tests).

  ## Lifecycle

  Application shutdown is delegated to OTP. `Application.stop(:otel)`
  drives the supervisor down, which calls
  `Otel.Metrics.MetricReader.PeriodicExporting.terminate/2`
  to perform a final collect/export and shut the exporter.
  There is no `shutdown/1` API on this module.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/0` | **SDK** (boot hook) — create ETS, seed `:persistent_term` |
  | `get_meter/0` | **Application** — Get a Meter |
  | `resource/0`, `config/0` | **Application** (introspection) |
  | `delete_storage/0` | **SDK** (test cleanup) — drop ETS tables |

  ## References

  - OTel Metrics SDK §MeterProvider: `opentelemetry-specification/specification/metrics/sdk.md` L43-L155
  """

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
          reader_id: reference() | nil
        }

  @doc """
  **SDK** (boot hook) — Called once from
  `Otel.Application.start/2` (or from `Otel.TestSupport` for
  tests) to create the named ETS tables and seed the
  `:persistent_term` slot. `exemplar_filter` is hardcoded to
  `:trace_based` (spec default per `metrics/sdk.md` L1123); only
  the resource flows from the user's
  `config :otel, resource: %{...}`.

  Idempotent: a second call replaces the persistent_term slot
  and reuses the existing ETS tables (or creates them if
  missing).
  """
  @spec init() :: :ok
  def init do
    ensure_tables!()

    resource = Otel.Resource.from_app_env()
    reader_id = make_ref()

    base_meter_config = %{
      resource: resource,
      instruments_tab: :otel_instruments,
      streams_tab: :otel_streams,
      metrics_tab: :otel_metrics,
      callbacks_tab: :otel_callbacks,
      exemplars_tab: :otel_exemplars,
      observed_attrs_tab: :otel_observed_attrs,
      exemplar_filter: :trace_based
    }

    reader_meter_config =
      base_meter_config
      |> Map.put(:reader_id, reader_id)
      |> Map.put(:temporality_mapping, Otel.Metrics.Instrument.default_temporality_mapping())

    :persistent_term.put(@persistent_key, %{
      resource: resource,
      exemplar_filter: :trace_based,
      base_meter_config: base_meter_config,
      reader_meter_config: reader_meter_config,
      reader_id: reader_id
    })

    :ok
  end

  @doc """
  **SDK** (test cleanup) — Drops all named ETS tables and the
  persistent_term slot. Called from `Otel.TestSupport.stop_all/0`
  so each test starts from a clean slate.

  Each `:ets.delete/1` is wrapped in a `try/rescue` because the
  table's owning process may die concurrently with `stop_all`
  (e.g., when `Application.stop(:otel)` happens just before this
  runs and the app controller process owned the tables): the
  `whereis/1` check sees a live table, but the table is gone by
  the time `delete/1` fires. CI runs hit this race; local runs
  rarely do.
  """
  @spec delete_storage() :: :ok
  def delete_storage do
    Enum.each(@ets_tables, fn name ->
      try do
        :ets.delete(name)
      rescue
        ArgumentError -> :ok
      end
    end)

    :persistent_term.erase(@persistent_key)
    :ok
  end

  @doc """
  **Application** — Get a Meter
  (`metrics/api.md` §Get a Meter).

  Returns a configured `%Otel.Metrics.Meter{}` struct stamped
  with the boot-time meter config and the SDK's hardcoded
  instrumentation scope (see `Otel.InstrumentationScope`).
  """
  @spec get_meter() :: Otel.Metrics.Meter.t()
  def get_meter do
    state = state()
    reader_meter_config = state.reader_meter_config
    reader_opts = %{temporality_mapping: reader_meter_config.temporality_mapping}

    meter_config =
      Map.merge(state.base_meter_config, %{
        scope: %Otel.InstrumentationScope{},
        reader_configs: [{state.reader_id, reader_opts}]
      })

    %Otel.Metrics.Meter{config: meter_config}
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
      reader_id: nil
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
end
