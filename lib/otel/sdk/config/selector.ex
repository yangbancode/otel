defmodule Otel.SDK.Config.Selector do
  @moduledoc """
  Atom-name → canonical module normalization for SDK
  configuration values.

  ## Public API

  | Function | Spec section |
  |---|---|
  | `propagator/1` | `sdk-environment-variables.md` L122-L131 (`OTEL_PROPAGATORS`) |

  Sampler / processor / exporter / id-generator selection is
  intentionally absent — those components are hardcoded:

  - Sampler: `parentbased_always_on` (`Otel.SDK.Trace.Sampler`)
  - Span/Log processors: batch implementation
    (`Otel.SDK.Trace.SpanProcessor`, `Otel.SDK.Logs.LogRecordProcessor`)
  - Exporters: OTLP/HTTP only (`Otel.OTLP.Trace.SpanExporter.HTTP`
    + metrics + logs counterparts). Console is intentionally not
    shipped — operators wanting a quick stdout view should run a
    local `opentelemetry-collector` with a logging exporter, or
    disable the SDK entirely (`config :otel, disabled: true`).
  - ID generator: random (`Otel.SDK.Trace.IdGenerator`)
  """

  # ====== Propagators ======

  @doc """
  Normalizes a single-propagator selector to a module reference.

  Spec L122-L131 enumerates eight known values; this SDK
  implements three: `:tracecontext`, `:baggage`, and `:none`.
  Other spec-named propagators (`:b3`, `:b3multi`, `:jaeger`,
  `:xray`, `:ottrace`) raise `ArgumentError` — their behaviours
  are not bundled in this package.

  Custom propagator modules pass through unchanged so users can
  plug their own implementations of
  `Otel.API.Propagator.TextMap`.
  """
  @spec propagator(value :: atom() | module()) :: module()
  def propagator(:tracecontext), do: Otel.API.Propagator.TextMap.TraceContext
  def propagator(:baggage), do: Otel.API.Propagator.TextMap.Baggage
  def propagator(:none), do: Otel.API.Propagator.TextMap.Noop

  def propagator(name) when name in [:b3, :b3multi, :jaeger, :xray, :ottrace] do
    raise ArgumentError,
          "propagator #{inspect(name)} is not implemented in this SDK — " <>
            "supported built-ins: :tracecontext, :baggage, :none"
  end

  def propagator(module) when is_atom(module), do: module
end
