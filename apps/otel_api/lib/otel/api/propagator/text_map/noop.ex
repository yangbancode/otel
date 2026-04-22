defmodule Otel.API.Propagator.TextMap.Noop do
  @moduledoc """
  No-op TextMap propagator used when no propagator is
  explicitly configured (spec `context/api-propagators.md`
  L322-L325, Status: **Stable**).

  Spec L322-L325 MUST:

  > *"The OpenTelemetry API MUST use no-op propagators unless
  > explicitly configured otherwise."*

  Registered as the default propagator by
  `Otel.API.Propagator.TextMap.get_propagator/0` — when no
  propagator is installed via `set_propagator/1`, this module
  is returned so that `inject/3` and `extract/3` always have
  a working propagator to dispatch to. This matches the shape
  used by `Otel.API.Trace.Tracer.Noop`,
  `Otel.API.Metrics.Meter.Noop`, and
  `Otel.API.Logs.Logger.Noop`.

  ## Invariants (spec L322-L325)

  - `inject/3` returns the carrier unchanged — no header is
    written.
  - `extract/3` returns the context unchanged — no value is
    stored.
  - `fields/0` returns `[]` — no headers are read or written.
  - No state held, no configuration, no logs emitted.

  ## Public API

  | Function | Role |
  |---|---|
  | `inject/3` | **OTel API MUST** — TextMap Inject (no-op) |
  | `extract/3` | **OTel API MUST** — TextMap Extract (no-op) |
  | `fields/0` | **OTel API** — Fields (empty list) |

  ## References

  - OTel Context §Global Propagators: `opentelemetry-specification/specification/context/api-propagators.md` L308-L346
  - OTel Context §TextMap Propagator: `opentelemetry-specification/specification/context/api-propagators.md` L114-L203
  """

  @behaviour Otel.API.Propagator.TextMap

  @doc """
  **OTel API MUST** — No-op Inject.

  Returns the carrier unchanged. The `ctx` and `setter`
  parameters are accepted for behaviour conformance but
  unused.
  """
  @impl true
  @spec inject(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          setter :: Otel.API.Propagator.TextMap.setter()
        ) :: Otel.API.Propagator.TextMap.carrier()
  def inject(_ctx, carrier, _setter), do: carrier

  @doc """
  **OTel API MUST** — No-op Extract.

  Returns the context unchanged. The `carrier` and `getter`
  parameters are accepted for behaviour conformance but
  unused. Naturally satisfies spec L100-L102
  *"MUST NOT throw on parse failure"* and
  *"MUST NOT store a new value"*.
  """
  @impl true
  @spec extract(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Ctx.t()
  def extract(ctx, _carrier, _getter), do: ctx

  @doc """
  **OTel API** — Fields.

  Returns `[]` — the no-op propagator reads and writes no
  headers.
  """
  @impl true
  @spec fields() :: [String.t()]
  def fields, do: []
end
