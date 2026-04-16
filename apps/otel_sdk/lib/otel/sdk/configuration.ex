defmodule Otel.SDK.Configuration do
  @moduledoc false

  @doc """
  Returns the default SDK configuration.

  Single source of truth — used by Application and TracerProvider.
  """
  @spec default_config() :: map()
  def default_config do
    %{
      sampler:
        {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}},
      processors: [],
      id_generator: Otel.SDK.Trace.IdGenerator.Default,
      resource: build_resource(),
      span_limits: %Otel.SDK.Trace.SpanLimits{}
    }
  end

  @doc """
  Merges default config, Application env, and OS environment variables.

  Priority: OS env vars > Application config > defaults.
  Empty env var values are treated as unset.
  """
  @spec merge(app_config :: map()) :: map()
  def merge(app_config) do
    env_config = read_env_vars()

    default_config()
    |> Map.merge(app_config)
    |> Map.merge(env_config)
  end

  @spec build_resource() :: Otel.SDK.Resource.t()
  defp build_resource do
    Otel.SDK.Resource.merge(Otel.SDK.Resource.default(), Otel.SDK.Resource.from_env())
  end

  @spec read_env_vars() :: map()
  defp read_env_vars do
    %{}
    |> maybe_put_sampler()
    |> maybe_put_span_limits()
    |> maybe_put_metrics_env()
    |> maybe_put_logs_env()
  end

  # --- Sampler ---

  @spec maybe_put_sampler(config :: map()) :: map()
  defp maybe_put_sampler(config) do
    case get_env("OTEL_TRACES_SAMPLER") do
      nil ->
        config

      sampler_name ->
        arg = get_env("OTEL_TRACES_SAMPLER_ARG")
        Map.put(config, :sampler, parse_sampler(sampler_name, arg))
    end
  end

  @spec parse_sampler(name :: String.t(), arg :: String.t() | nil) :: {module(), term()}
  defp parse_sampler("always_on", _arg), do: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}
  defp parse_sampler("always_off", _arg), do: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}

  defp parse_sampler("traceidratio", arg) do
    probability = parse_float(arg, 1.0)
    {Otel.SDK.Trace.Sampler.TraceIdRatioBased, %{probability: probability}}
  end

  defp parse_sampler("parentbased_always_on", _arg) do
    {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
  end

  defp parse_sampler("parentbased_always_off", _arg) do
    {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}}}
  end

  defp parse_sampler("parentbased_traceidratio", arg) do
    probability = parse_float(arg, 1.0)

    {Otel.SDK.Trace.Sampler.ParentBased,
     %{root: {Otel.SDK.Trace.Sampler.TraceIdRatioBased, %{probability: probability}}}}
  end

  defp parse_sampler(_unknown, _arg), do: nil

  # --- Span Limits ---

  @spec maybe_put_span_limits(config :: map()) :: map()
  defp maybe_put_span_limits(config) do
    limits = %{}
    limits = maybe_put_int(limits, :attribute_count_limit, "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT")

    limits =
      maybe_put_int_or_infinity(
        limits,
        :attribute_value_length_limit,
        "OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT"
      )

    limits = maybe_put_int(limits, :event_count_limit, "OTEL_SPAN_EVENT_COUNT_LIMIT")
    limits = maybe_put_int(limits, :link_count_limit, "OTEL_SPAN_LINK_COUNT_LIMIT")
    limits = maybe_put_int(limits, :attribute_per_event_limit, "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT")
    limits = maybe_put_int(limits, :attribute_per_link_limit, "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT")

    if map_size(limits) > 0 do
      default_limits = Map.get(config, :span_limits, %Otel.SDK.Trace.SpanLimits{})
      Map.put(config, :span_limits, struct(default_limits, limits))
    else
      config
    end
  end

  # --- Metrics ---

  @spec maybe_put_metrics_env(config :: map()) :: map()
  defp maybe_put_metrics_env(config) do
    metrics = %{}
    metrics = maybe_put_metrics_exporter(metrics)
    metrics = maybe_put_exemplar_filter(metrics)
    metrics = maybe_put_metric_export_interval(metrics)
    metrics = maybe_put_metric_export_timeout(metrics)

    if map_size(metrics) > 0 do
      Map.put(config, :metrics, metrics)
    else
      config
    end
  end

  @spec maybe_put_metrics_exporter(config :: map()) :: map()
  defp maybe_put_metrics_exporter(config) do
    case get_env("OTEL_METRICS_EXPORTER") do
      nil -> config
      value -> Map.put(config, :exporter, parse_metrics_exporter(value))
    end
  end

  @spec parse_metrics_exporter(value :: String.t()) :: atom()
  defp parse_metrics_exporter("otlp"), do: :otlp
  defp parse_metrics_exporter("console"), do: :console
  defp parse_metrics_exporter("none"), do: :none
  defp parse_metrics_exporter(_), do: :otlp

  @spec maybe_put_exemplar_filter(config :: map()) :: map()
  defp maybe_put_exemplar_filter(config) do
    case get_env("OTEL_METRICS_EXEMPLAR_FILTER") do
      nil -> config
      value -> Map.put(config, :exemplar_filter, parse_exemplar_filter(value))
    end
  end

  @spec parse_exemplar_filter(value :: String.t()) :: Otel.SDK.Metrics.Exemplar.Filter.t()
  defp parse_exemplar_filter("always_on"), do: :always_on
  defp parse_exemplar_filter("always_off"), do: :always_off
  defp parse_exemplar_filter("trace_based"), do: :trace_based
  defp parse_exemplar_filter(_), do: :trace_based

  @spec maybe_put_metric_export_interval(config :: map()) :: map()
  defp maybe_put_metric_export_interval(config) do
    maybe_put_int(config, :export_interval_ms, "OTEL_METRIC_EXPORT_INTERVAL")
  end

  @spec maybe_put_metric_export_timeout(config :: map()) :: map()
  defp maybe_put_metric_export_timeout(config) do
    maybe_put_int(config, :export_timeout_ms, "OTEL_METRIC_EXPORT_TIMEOUT")
  end

  # --- Logs ---

  @spec maybe_put_logs_env(config :: map()) :: map()
  defp maybe_put_logs_env(config) do
    logs = %{}
    logs = maybe_put_logs_exporter(logs)
    logs = maybe_put_log_record_limits(logs)
    logs = maybe_put_blrp_env(logs)

    if map_size(logs) > 0 do
      Map.put(config, :logs, logs)
    else
      config
    end
  end

  @spec maybe_put_logs_exporter(config :: map()) :: map()
  defp maybe_put_logs_exporter(config) do
    case get_env("OTEL_LOGS_EXPORTER") do
      nil -> config
      value -> Map.put(config, :exporter, parse_logs_exporter(value))
    end
  end

  @spec parse_logs_exporter(value :: String.t()) :: atom()
  defp parse_logs_exporter("otlp"), do: :otlp
  defp parse_logs_exporter("console"), do: :console
  defp parse_logs_exporter("none"), do: :none
  defp parse_logs_exporter(_), do: :otlp

  @spec maybe_put_log_record_limits(config :: map()) :: map()
  defp maybe_put_log_record_limits(config) do
    limits = %{}

    limits =
      maybe_put_int(limits, :attribute_count_limit, "OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT")

    limits =
      maybe_put_int_or_infinity(
        limits,
        :attribute_value_length_limit,
        "OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT"
      )

    if map_size(limits) > 0 do
      Map.put(config, :log_record_limits, struct(Otel.SDK.Logs.LogRecordLimits, limits))
    else
      config
    end
  end

  @spec maybe_put_blrp_env(config :: map()) :: map()
  defp maybe_put_blrp_env(config) do
    blrp = %{}
    blrp = maybe_put_int(blrp, :scheduled_delay_ms, "OTEL_BLRP_SCHEDULE_DELAY")
    blrp = maybe_put_int(blrp, :export_timeout_ms, "OTEL_BLRP_EXPORT_TIMEOUT")
    blrp = maybe_put_int(blrp, :max_queue_size, "OTEL_BLRP_MAX_QUEUE_SIZE")
    blrp = maybe_put_int(blrp, :max_export_batch_size, "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE")

    if map_size(blrp) > 0 do
      Map.put(config, :blrp, blrp)
    else
      config
    end
  end

  # --- Parsing helpers ---

  @spec get_env(name :: String.t()) :: String.t() | nil
  defp get_env(name) do
    case System.get_env(name) do
      nil -> nil
      "" -> nil
      value -> String.downcase(String.trim(value))
    end
  end

  @spec maybe_put_int(map :: map(), key :: atom(), env_name :: String.t()) :: map()
  defp maybe_put_int(map, key, env_name) do
    case get_env_raw(env_name) do
      nil -> map
      value -> Map.put(map, key, parse_int(value))
    end
  end

  @spec maybe_put_int_or_infinity(map :: map(), key :: atom(), env_name :: String.t()) :: map()
  defp maybe_put_int_or_infinity(map, key, env_name) do
    case get_env_raw(env_name) do
      nil -> map
      value -> Map.put(map, key, parse_int_or_infinity(value))
    end
  end

  @spec get_env_raw(name :: String.t()) :: String.t() | nil
  defp get_env_raw(name) do
    case System.get_env(name) do
      nil -> nil
      "" -> nil
      value -> String.trim(value)
    end
  end

  @spec parse_int(value :: String.t()) :: integer()
  defp parse_int(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> 0
    end
  end

  @spec parse_int_or_infinity(value :: String.t()) :: integer() | :infinity
  defp parse_int_or_infinity(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> :infinity
    end
  end

  @spec parse_float(value :: String.t() | nil, default :: float()) :: float()
  defp parse_float(nil, default), do: default

  defp parse_float(value, default) do
    case Float.parse(value) do
      {f, ""} -> f
      _ -> default
    end
  end
end
