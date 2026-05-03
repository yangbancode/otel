defmodule Otel.Metrics.MeterProvider do
  @moduledoc """
  MeterProvider — minikube hardcoded.

  Issues `%Otel.Metrics.Meter{}` structs. Holds no process or
  persistent state; the SDK's only user-tunable knob is the
  `:resource` `Application` env, which `Otel.Resource.from_app_env/0`
  reads on every call. Every other knob (scope, exemplar filter,
  ETS table identifiers, reader id, temporality mapping) is a
  compile-time literal.

  `init/0` runs once from `Otel.Application.start/2` to create
  the named ETS tables that hold metrics state; the tables are
  owned by the caller process (the SDK Application controller in
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
  | `init/0` | **SDK** (boot hook) — create the named ETS tables |
  | `get_meter/0` | **Application** — Get a Meter |
  | `resource/0`, `config/0` | **Application** (introspection) |
  | `delete_storage/0` | **SDK** (test cleanup) — drop ETS tables |

  ## References

  - OTel Metrics SDK §MeterProvider: `opentelemetry-specification/specification/metrics/sdk.md` L43-L155
  """

  # Hardcoded identifiers shared by Meter and MetricReader.
  # `reader_id` was a `make_ref/0` reference back when the SDK
  # supported multiple readers; minikube has exactly one, so a
  # stable atom suffices and removes the only thing left that
  # genuinely needed boot-time persistence.
  @reader_id :default_reader

  @ets_tables [
    :otel_instruments,
    :otel_streams,
    :otel_metrics,
    :otel_callbacks,
    :otel_exemplars,
    :otel_observed_attrs
  ]

  @doc """
  **SDK** (boot hook) — Called once from
  `Otel.Application.start/2` (or from `Otel.TestSupport` for
  tests) to create the named ETS tables. Idempotent — a
  second call reuses the existing tables (or creates them if
  missing).
  """
  @spec init() :: :ok
  def init do
    ensure_tables!()
    :ok
  end

  @doc """
  **SDK** (test cleanup) — Drops all named ETS tables. Called
  from `Otel.TestSupport.stop_all/0` so each test starts from
  a clean slate.

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

    :ok
  end

  @doc """
  **Application** — Get a Meter
  (`metrics/api.md` §Get a Meter).

  Returns a configured `%Otel.Metrics.Meter{}` struct stamped
  with the SDK's hardcoded instrumentation scope (see
  `Otel.InstrumentationScope`), the resolved resource, and
  the named ETS table handles + reader id used by the
  collect/record paths.
  """
  @spec get_meter() :: Otel.Metrics.Meter.t()
  def get_meter, do: %Otel.Metrics.Meter{config: meter_config()}

  @doc """
  **SDK** — Returns the meter config the
  `Otel.Metrics.MetricReader.PeriodicExporting` reader uses to
  collect from the named ETS tables. Same map as the config
  stamped on a `%Meter{}` by `get_meter/0` — `meter_config/0`
  carries both the producer-side `reader_configs` and the
  consumer-side `reader_id` + `temporality_mapping` so either
  caller can use the same map.
  """
  @spec reader_meter_config() :: map()
  def reader_meter_config, do: meter_config()

  @doc """
  **Application** (introspection) — Returns the resource
  resolved from the `:otel` `:resource` `Application` env, or
  `Otel.Resource.default/0` when no env is set.
  """
  @spec resource() :: Otel.Resource.t()
  def resource, do: Otel.Resource.from_app_env()

  @doc """
  **Application** (introspection) — Returns a synthetic
  config map with the resolved resource and the same shape
  the boot-time snapshot used to expose.
  """
  @spec config() :: map()
  def config, do: meter_config()

  # --- Private ---

  @spec meter_config() :: map()
  defp meter_config do
    temporality_mapping = Otel.Metrics.Instrument.default_temporality_mapping()

    %{
      scope: %Otel.InstrumentationScope{},
      resource: Otel.Resource.from_app_env(),
      instruments_tab: :otel_instruments,
      streams_tab: :otel_streams,
      metrics_tab: :otel_metrics,
      callbacks_tab: :otel_callbacks,
      exemplars_tab: :otel_exemplars,
      observed_attrs_tab: :otel_observed_attrs,
      exemplar_filter: :trace_based,
      # Consumer-side keys for `MetricReader.collect/1` —
      # `meter.config` is interchangeable with the reader's
      # collect config so callers don't have to juggle two shapes.
      reader_id: @reader_id,
      temporality_mapping: temporality_mapping,
      # Producer-side key for `Meter.record/3` — single-element
      # since minikube has exactly one reader.
      reader_configs: [{@reader_id, %{temporality_mapping: temporality_mapping}}]
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
