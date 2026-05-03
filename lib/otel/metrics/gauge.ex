defmodule Otel.Metrics.Gauge do
  @moduledoc """
  Synchronous Gauge instrument facade (OTel `metrics/api.md`
  §Gauge, Status: **Stable**, L828-L916).

  A Gauge records non-additive value(s) when changes occur
  (spec L830-L833). Non-additive means summing values from
  multiple sources is nonsensical (background noise level
  from several rooms doesn't aggregate). Example uses:
  change-event subscriptions for background noise level or
  CPU fan speed (spec L849-L850).

  Per spec L835-L837, use `UpDownCounter` when values are
  additive. Per spec L839-L845, use this synchronous Gauge
  when measurements are pushed via change-event
  subscriptions (`value -> gauge.record(value)`); use the
  asynchronous `Otel.Metrics.ObservableGauge` when
  values are pulled via an accessor function.

  Created exclusively through a `Meter` per spec L854
  *"MUST NOT be any API for creating a Gauge other than
  with a Meter"*.

  ## Absolute-value contract

  Per spec L883-L885, `record/3` takes the **current
  absolute value** — not a delta. The recording replaces
  the previous value for a given set of attributes rather
  than accumulating. Spec imposes no sign constraint (no
  non-negative SHOULD, unlike Counter and Histogram).

  ## BEAM representation

  `opentelemetry-erlang` has **no** synchronous Gauge
  facade — the sync Gauge was added to the spec after the
  erlang reference was written, and erlang's
  `opentelemetry_api_experimental` currently ships only
  `ObservableGauge`. This module fills that gap so our
  Metrics API surface is complete across all four
  synchronous instruments defined by the spec.

  When an erlang-side counterpart eventually appears, the
  expected pattern (matching the other sync instruments
  there) is a `defmacro` with implicit meter via
  `opentelemetry_experimental:get_meter/1` and injected
  `OpenTelemetry.Ctx.get_current()`. We deliberately use
  plain `def` with an explicit `Meter.t()` handle — a
  BEAM-Elixir idiom consistent with the `Tracer` and
  `Meter` facades project-wide — and we do not thread
  context through `record/3` because synchronous metric
  measurements are not context-associated at the API
  boundary.


  All functions are safe for concurrent use (spec
  L1351-L1352, §Concurrency §Instrument).

  ## Public API

  | Function | Role |
  |---|---|
  | `create/3` | **Application** (OTel API MUST) — Gauge creation (L852-L872) |
  | `record/3` | **Application** (OTel API MUST) — Gauge Record (L876-L915) |

  ## References

  - OTel Metrics API §Gauge: `opentelemetry-specification/specification/metrics/api.md` L828-L916
  - OTel Metrics API §Synchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L302-L348
  - OTel Metrics API §Concurrency §Instrument: `opentelemetry-specification/specification/metrics/api.md` L1351-L1352
  """

  use Otel.Common.Types

  @doc """
  **Application** (OTel API MUST) — "Gauge creation"
  (`metrics/api.md` §Gauge creation, L852-L872).

  Creates the instrument handle via the given Meter. Per
  spec L854, there is no other API surface for creating a
  Gauge.

  Options (per §Synchronous Instrument API L302-L348):

  - `:unit` — case-sensitive ASCII string, max 63 chars
  - `:description` — opaque string (BMP Plane 0), at least
    1023 chars supported
  - `:advisory` — advisory parameters

  Delegates to `Otel.Metrics.Meter.create_gauge/3`.
  """
  @spec create(
          name :: String.t(),
          opts :: Otel.Metrics.Instrument.create_opts()
        ) :: Otel.Metrics.Instrument.t()
  def create(name, opts \\ []) do
    Otel.Metrics.Meter.create_gauge(name, opts)
  end

  @doc """
  **Application** (OTel API MUST) — "Record" (`metrics/api.md`
  §Gauge operations — Record, L876-L915).

  Records the current absolute value of the Gauge. Per
  spec L883-L885 the value is a numeric absolute reading,
  not a delta — the recording replaces the previous value
  for the given attribute set.

  Attributes default to `%{}` per spec L891-L895 *"MUST be
  structured to accept a variable number of attributes,
  including none"*.


  Delegates to `Otel.Metrics.Meter.record/3` — both
  Gauge.record and the synchronous siblings share a single
  Meter dispatch.
  """
  @spec record(
          instrument :: Otel.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive_any()}
        ) :: :ok
  def record(instrument, value, attributes \\ %{}) do
    Otel.Metrics.Meter.record(instrument, value, attributes)
  end
end
