defmodule Otel.E2E.Emitter do
  @moduledoc """
  Helpers for emitting telemetry from e2e tests. Each helper tags
  the emitted record with the supplied `e2e_id` (under attribute
  `e2e.id`) and force-flushes the corresponding pillar so the data
  is on its way to the collector by return.
  """

  @scope %Otel.API.InstrumentationScope{name: "e2e", version: "1.0.0"}

  @doc "InstrumentationScope used by every e2e helper."
  def scope, do: @scope

  @doc """
  Restarts `:otel` with `OTEL_SERVICE_NAME=name` so the resource
  carries a recognisable `service.name` (used by Tempo / Loki to
  index by service).
  """
  @spec setup_service_name(name :: String.t()) :: :ok
  def setup_service_name(name) do
    Application.stop(:otel)
    System.put_env("OTEL_SERVICE_NAME", name)
    {:ok, _} = Application.ensure_all_started(:otel)
    :ok
  end

  @doc """
  Emits a span via `with_span/4` and force-flushes traces. Extra
  span attributes (beyond `e2e.id`) can be passed via `attributes:`.
  Other `start_opts()` keys (`kind:`, `links:`, …) pass through.
  """
  @spec emit_span(name :: String.t(), e2e_id :: String.t(), opts :: keyword()) :: term()
  def emit_span(name, e2e_id, opts \\ []) do
    {extra_attrs, opts} = Keyword.pop(opts, :attributes, %{})
    {fun, opts} = Keyword.pop(opts, :run, fn _ -> :ok end)

    tracer = Otel.API.Trace.TracerProvider.get_tracer(@scope)
    attrs = Map.put(extra_attrs, "e2e.id", e2e_id)

    result = Otel.API.Trace.with_span(tracer, name, [attributes: attrs] ++ opts, fun)

    flush_traces()
    result
  end

  @doc """
  Emits a log record via the SDK API and force-flushes logs.
  """
  @spec emit_log(body :: term(), e2e_id :: String.t(), opts :: keyword()) :: :ok
  def emit_log(body, e2e_id, opts \\ []) do
    {extra_attrs, opts} = Keyword.pop(opts, :attributes, %{})
    severity_number = Keyword.get(opts, :severity_number, 9)
    severity_text = Keyword.get(opts, :severity_text, "info")

    logger = Otel.API.Logs.LoggerProvider.get_logger(@scope)
    attrs = Map.put(extra_attrs, "e2e.id", e2e_id)

    Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
      body: body,
      severity_number: severity_number,
      severity_text: severity_text,
      attributes: attrs
    })

    flush_logs()
    :ok
  end

  @doc """
  Increments a counter by 1 (or `value`) and force-flushes metrics.
  Counter creation opts (`unit:`, `description:`, …) pass through;
  emit-time `attributes:` are merged with the e2e_id.
  """
  @spec emit_counter(name :: String.t(), e2e_id :: String.t(), opts :: keyword()) :: :ok
  def emit_counter(name, e2e_id, opts \\ []) do
    {extra_attrs, opts} = Keyword.pop(opts, :attributes, %{})
    {value, create_opts} = Keyword.pop(opts, :value, 1)

    meter = Otel.API.Metrics.MeterProvider.get_meter(@scope)
    counter = Otel.API.Metrics.Meter.create_counter(meter, name, create_opts)
    attrs = Map.put(extra_attrs, "e2e.id", e2e_id)

    Otel.API.Metrics.Counter.add(counter, value, attrs)

    flush_metrics()
    :ok
  end

  defp flush_traces, do: Otel.SDK.Trace.TracerProvider.force_flush(Otel.SDK.Trace.TracerProvider)
  defp flush_logs, do: Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)

  defp flush_metrics,
    do: Otel.SDK.Metrics.MeterProvider.force_flush(Otel.SDK.Metrics.MeterProvider)
end
