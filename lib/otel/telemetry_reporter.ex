defmodule Otel.TelemetryReporter do
  @moduledoc """
  `Telemetry.Metrics` reporter that bridges BEAM `:telemetry`
  events into the OTel Metrics pipeline. Mirror of
  `Otel.LoggerHandler` for the metrics pillar.

  Add it to your supervision tree with a list of
  `Telemetry.Metrics` definitions:

      defmodule MyApp.Application do
        use Application

        @impl true
        def start(_type, _args) do
          children = [
            {Otel.TelemetryReporter, metrics: metrics()}
          ]
          Supervisor.start_link(children, strategy: :one_for_one)
        end

        defp metrics do
          import Telemetry.Metrics

          [
            counter("phoenix.endpoint.stop.duration"),
            summary("phoenix.endpoint.stop.duration",
              unit: {:native, :millisecond}
            ),
            last_value("vm.memory.total", unit: {:byte, :kilobyte})
          ]
        end
      end

  ## Type mapping

  | `Telemetry.Metrics`        | OTel instrument                   | dispatch                                               |
  |---------------------------|-----------------------------------|--------------------------------------------------------|
  | `counter/2`               | `Otel.Metrics.Counter`            | `Counter.add(inst, 1, attrs)` — measurement ignored    |
  | `sum/2`                   | `Otel.Metrics.UpDownCounter`      | `UpDownCounter.add(inst, value, attrs)`                |
  | `last_value/2`            | `Otel.Metrics.Gauge`              | `Gauge.record(inst, value, attrs)`                     |
  | `summary/2`               | `Otel.Metrics.Histogram`          | `Histogram.record(inst, value, attrs)`                 |
  | `distribution/2`          | `Otel.Metrics.Histogram`          | `Histogram.record(inst, value, attrs)` (uses buckets) |

  `Telemetry.Metrics.Sum` carries no monotonic flag, so the
  reporter conservatively maps it to `UpDownCounter`. If your
  source values are guaranteed non-negative and you want monotonic
  Sum semantics, pass `reporter_options: [monotonic: true]`:

      sum("http.request.bytes_sent", reporter_options: [monotonic: true])

  ## Tags / tag_values

  `metric.tags` selects which metadata keys to use as OTel
  attribute keys; `metric.tag_values` (default identity) can
  pre-process metadata before extraction. Tag values are
  string-coerced (atoms via `Atom.to_string/1`, others kept
  as-is) on dispatch.

  ## Unit conversion

  Unit conversion is performed by `Telemetry.Metrics` itself
  at metric-definition time: when you pass `unit: {from, to}`,
  the metric's `:measurement` field is wrapped to convert
  values into the target unit before they reach this reporter.
  We forward the resulting target-unit atom (e.g.
  `:millisecond`, `:kilobyte`) to the OTel instrument's `unit`
  field. Note byte conversions are **decimal** per
  `Telemetry.Metrics` convention (1 kB = 1000 B).

  ## :keep / :drop predicates

  Honored per `Telemetry.Metrics`: when `:keep` returns false or
  `:drop` returns true, the measurement is skipped — the OTel
  instrument is not updated.

  ## Lifecycle

  The reporter is a `GenServer` with `trap_exit: true`. Each
  registered telemetry event gets a `:telemetry.attach` keyed by
  `{__MODULE__, event_name, self()}`. On `terminate/2` (supervisor
  shutdown), every handler is detached so reloads / restarts
  don't leave dangling handlers.

  ## References

  - `Telemetry.Metrics`: <https://hexdocs.pm/telemetry_metrics>
  - `Telemetry.Metrics.ConsoleReporter` — reference shape we
    mirror (group-by-event attach, single handle_event dispatch)
  """

  use GenServer
  require Logger

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    server_opts = Keyword.take(opts, [:name])

    metrics =
      opts[:metrics] ||
        raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"

    GenServer.start_link(__MODULE__, metrics, server_opts)
  end

  @impl true
  def init(metrics) do
    Process.flag(:trap_exit, true)

    instruments =
      Map.new(metrics, fn metric -> {metric_id(metric), ensure_instrument(metric)} end)

    groups = Enum.group_by(metrics, & &1.event_name)

    for {event, evt_metrics} <- groups do
      id = {__MODULE__, event, self()}
      :telemetry.attach(id, event, &__MODULE__.handle_event/4, {evt_metrics, instruments})
    end

    {:ok, %{events: Map.keys(groups)}}
  end

  @impl true
  def terminate(_reason, %{events: events}) do
    for event <- events, do: :telemetry.detach({__MODULE__, event, self()})
    :ok
  end

  @doc false
  def handle_event(_event_name, measurements, metadata, {metrics, instruments}) do
    for metric <- metrics do
      try do
        dispatch_metric(metric, instruments[metric_id(metric)], measurements, metadata)
      rescue
        e ->
          Logger.error([
            "Otel.TelemetryReporter could not dispatch #{inspect(metric)}\n",
            Exception.format(:error, e, __STACKTRACE__)
          ])
      end
    end

    :ok
  end

  # --- Instrument creation ---

  @spec ensure_instrument(metric :: Telemetry.Metrics.t()) :: Otel.Metrics.Instrument.t()
  defp ensure_instrument(%Telemetry.Metrics.Counter{} = metric) do
    Otel.Metrics.Counter.create(metric_name(metric), unit: target_unit(metric.unit))
  end

  defp ensure_instrument(%Telemetry.Metrics.Sum{} = metric) do
    if reporter_option(metric, :monotonic, false) do
      Otel.Metrics.Counter.create(metric_name(metric), unit: target_unit(metric.unit))
    else
      Otel.Metrics.UpDownCounter.create(metric_name(metric), unit: target_unit(metric.unit))
    end
  end

  defp ensure_instrument(%Telemetry.Metrics.LastValue{} = metric) do
    Otel.Metrics.Gauge.create(metric_name(metric), unit: target_unit(metric.unit))
  end

  defp ensure_instrument(%Telemetry.Metrics.Summary{} = metric) do
    Otel.Metrics.Histogram.create(metric_name(metric), unit: target_unit(metric.unit))
  end

  defp ensure_instrument(%Telemetry.Metrics.Distribution{} = metric) do
    boundaries = reporter_option(metric, :buckets, nil)

    advisory =
      if is_list(boundaries),
        do: [explicit_bucket_boundaries: boundaries],
        else: []

    Otel.Metrics.Histogram.create(metric_name(metric),
      unit: target_unit(metric.unit),
      advisory: advisory
    )
  end

  # --- Dispatch ---

  @spec dispatch_metric(
          metric :: Telemetry.Metrics.t(),
          instrument :: Otel.Metrics.Instrument.t(),
          measurements :: map(),
          metadata :: map()
        ) :: :ok
  defp dispatch_metric(metric, instrument, measurements, metadata) do
    if keep?(metric, metadata, measurements) do
      attrs = build_attrs(metric, metadata)
      do_dispatch(metric, instrument, measurements, metadata, attrs)
    else
      :ok
    end
  end

  defp do_dispatch(%Telemetry.Metrics.Counter{}, instrument, _measurements, _metadata, attrs) do
    Otel.Metrics.Counter.add(instrument, 1, attrs)
  end

  defp do_dispatch(%Telemetry.Metrics.Sum{} = metric, instrument, measurements, metadata, attrs) do
    case extract_value(metric, measurements, metadata) do
      nil ->
        :ok

      value ->
        if reporter_option(metric, :monotonic, false) do
          Otel.Metrics.Counter.add(instrument, value, attrs)
        else
          Otel.Metrics.UpDownCounter.add(instrument, value, attrs)
        end
    end
  end

  defp do_dispatch(
         %Telemetry.Metrics.LastValue{} = metric,
         instrument,
         measurements,
         metadata,
         attrs
       ) do
    case extract_value(metric, measurements, metadata) do
      nil -> :ok
      value -> Otel.Metrics.Gauge.record(instrument, value, attrs)
    end
  end

  defp do_dispatch(
         %Telemetry.Metrics.Summary{} = metric,
         instrument,
         measurements,
         metadata,
         attrs
       ) do
    case extract_value(metric, measurements, metadata) do
      nil -> :ok
      value -> Otel.Metrics.Histogram.record(instrument, value, attrs)
    end
  end

  defp do_dispatch(
         %Telemetry.Metrics.Distribution{} = metric,
         instrument,
         measurements,
         metadata,
         attrs
       ) do
    case extract_value(metric, measurements, metadata) do
      nil -> :ok
      value -> Otel.Metrics.Histogram.record(instrument, value, attrs)
    end
  end

  # --- Helpers ---

  @spec metric_id(metric :: Telemetry.Metrics.t()) :: term()
  defp metric_id(metric), do: {metric.__struct__, metric.name}

  @spec metric_name(metric :: Telemetry.Metrics.t()) :: String.t()
  defp metric_name(%{name: name}) when is_list(name), do: Enum.join(name, ".")

  @spec keep?(metric :: Telemetry.Metrics.t(), metadata :: map(), measurements :: map()) ::
          boolean()
  defp keep?(metric, metadata, measurements) do
    # `Telemetry.Metrics` resolves `:keep` to either a 1- / 2-arity
    # predicate or `nil` (no `:keep` and no `:drop` set); the typespec
    # only documents the function form, so guard on shape and treat
    # everything else as "always keep".
    case metric.keep do
      keep when is_function(keep, 2) -> keep.(metadata, measurements)
      keep when is_function(keep, 1) -> keep.(metadata)
      _ -> true
    end
  end

  @spec build_attrs(metric :: Telemetry.Metrics.t(), metadata :: map()) ::
          %{String.t() => term()}
  defp build_attrs(%{tags: tags, tag_values: tag_values}, metadata) when is_list(tags) do
    transformed = tag_values.(metadata)

    Map.new(tags, fn key ->
      {Atom.to_string(key), coerce_attr_value(Map.get(transformed, key))}
    end)
  end

  defp coerce_attr_value(nil), do: nil
  defp coerce_attr_value(value) when is_atom(value), do: Atom.to_string(value)
  defp coerce_attr_value(value), do: value

  # Measurement extraction. `Telemetry.Metrics` has already
  # wrapped `metric.measurement` with any `{from, to}` unit
  # conversion at definition time, so we just call it.
  # Returns `nil` when the measurement is missing.
  @spec extract_value(metric :: Telemetry.Metrics.t(), measurements :: map(), metadata :: map()) ::
          number() | nil
  defp extract_value(metric, measurements, metadata) do
    case metric.measurement do
      fun when is_function(fun, 2) -> fun.(measurements, metadata)
      fun when is_function(fun, 1) -> fun.(measurements)
      key -> Map.get(measurements, key)
    end
  end

  # `Telemetry.Metrics.validate_unit!/1` reduces `{from, to}`
  # tuples to the target unit atom before construction, so
  # `metric.unit` is always an atom (or the `:unit` sentinel
  # meaning "unspecified"). Map both to OTel's `String.t()`
  # `unit` field.
  @spec target_unit(unit :: atom()) :: String.t()
  defp target_unit(:unit), do: ""
  defp target_unit(nil), do: ""
  defp target_unit(unit) when is_atom(unit), do: Atom.to_string(unit)

  @spec reporter_option(metric :: Telemetry.Metrics.t(), key :: atom(), default :: term()) ::
          term()
  defp reporter_option(%{reporter_options: opts}, key, default) when is_list(opts) do
    Keyword.get(opts, key, default)
  end
end
