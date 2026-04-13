defmodule Otel.SDK.Configuration do
  @moduledoc false

  @doc """
  Merges default config, Application env, and OS environment variables.

  Priority: OS env vars > Application config > defaults.
  Empty env var values are treated as unset.
  """
  @spec merge(default_config :: map(), app_config :: map()) :: map()
  def merge(default_config, app_config) do
    env_config = read_env_vars()

    default_config
    |> Map.merge(app_config)
    |> Map.merge(env_config)
  end

  @spec read_env_vars() :: map()
  defp read_env_vars do
    %{}
    |> maybe_put_sampler()
    |> maybe_put_span_limits()
    |> maybe_put_bsp()
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

  # --- Batch Span Processor ---

  @spec maybe_put_bsp(config :: map()) :: map()
  defp maybe_put_bsp(config) do
    bsp = %{}
    bsp = maybe_put_int(bsp, :scheduled_delay_ms, "OTEL_BSP_SCHEDULE_DELAY")
    bsp = maybe_put_int(bsp, :export_timeout_ms, "OTEL_BSP_EXPORT_TIMEOUT")
    bsp = maybe_put_int(bsp, :max_queue_size, "OTEL_BSP_MAX_QUEUE_SIZE")
    bsp = maybe_put_int(bsp, :max_export_batch_size, "OTEL_BSP_MAX_EXPORT_BATCH_SIZE")

    if map_size(bsp) > 0 do
      Map.put(config, :bsp_config, bsp)
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
