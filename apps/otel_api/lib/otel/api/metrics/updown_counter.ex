defmodule Otel.API.Metrics.UpDownCounter do
  @moduledoc """
  Synchronous UpDownCounter instrument facade (OTel
  `metrics/api.md` §UpDownCounter, Status: **Stable**,
  L1032-L1157).

  An UpDownCounter supports both increments and decrements
  recorded synchronously at the call site (spec
  L1034-L1035). Example uses: number of active requests,
  number of items in a queue (spec L1043-L1044).

  Per spec L1037-L1039, use `Counter` instead when the
  value is monotonically increasing. UpDownCounter is
  intended for scenarios where absolute values are not
  pre-calculated or fetching the current value requires
  extra effort (spec L1046-L1050); when a fresh snapshot
  is cheap, `Otel.API.Metrics.ObservableUpDownCounter`
  (with a callback) fits better.

  Created exclusively through a `Meter` per spec L1086
  *"MUST NOT be any API for creating an UpDownCounter
  other than with a Meter"*.

  ## Value contract

  Per spec L1125-L1132, the value is a numeric increment
  or decrement (positive, zero, or negative). Unlike
  `Counter`, there is **no non-negative constraint** — a
  negative value is a first-class legitimate input. See
  the inventory example in spec L1052-L1082 (adding and
  removing items from a concurrent bag).

  ## BEAM representation

  `opentelemetry-erlang` implements this as a `defmacro`
  that resolves the meter implicitly via
  `opentelemetry_experimental:get_meter/1` at expansion
  time and injects `OpenTelemetry.Ctx.get_current()` into
  `:otel_up_down_counter.add/5`
  (`lib/open_telemetry/updown_counter.ex`). We take a
  different path:

  - plain `def` with an explicit `Meter.t()` handle —
    macro-free, Dialyzer-visible, consistent with the
    `Tracer` and `Meter` facades project-wide
  - no implicit context threaded through `add/3` —
    synchronous metric measurements are not
    context-associated at the API boundary; the SDK
    attaches context per `Otel.API.Ctx` if relevant

  Erlang also does not expose `enabled?/2` on sync
  instruments; we add it per spec L475-L477 (SHOULD
  provide) and spec L479-L495 (Enabled API).

  All functions are safe for concurrent use (spec
  L1351-L1352, §Concurrency §Instrument).

  ## Public API

  | Function | Role |
  |---|---|
  | `create/3` | **OTel API MUST** (UpDownCounter creation, L1084-L1115) |
  | `add/3` | **OTel API MUST** (UpDownCounter Add, L1118-L1156) |
  | `enabled?/2` | **OTel API SHOULD** (Enabled, L479-L495) |

  ## References

  - OTel Metrics API §UpDownCounter: `opentelemetry-specification/specification/metrics/api.md` L1032-L1157
  - OTel Metrics API §Synchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L302-L348
  - OTel Metrics API §General operations / Enabled: `opentelemetry-specification/specification/metrics/api.md` L473-L495
  - OTel Metrics API §Concurrency §Instrument: `opentelemetry-specification/specification/metrics/api.md` L1351-L1352
  - Decision: `docs/decisions/synchronous-instruments.md`
  """

  use Otel.API.Common.Types

  @doc """
  **OTel API MUST** — "UpDownCounter creation"
  (`metrics/api.md` §UpDownCounter creation, L1084-L1115).

  Creates the instrument handle via the given Meter. Per
  spec L1086, there is no other API surface for creating an
  UpDownCounter.

  Options (per §Synchronous Instrument API L302-L348):

  - `:unit` — case-sensitive ASCII string, max 63 chars
  - `:description` — opaque string (BMP Plane 0), at least
    1023 chars supported
  - `:advisory` — advisory parameters

  Delegates to
  `Otel.API.Metrics.Meter.create_updown_counter/3`.
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_updown_counter(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Add" (`metrics/api.md`
  §UpDownCounter operations — Add, L1118-L1156).

  Increments or decrements the UpDownCounter by `value`.
  Per spec L1125-L1132 the value is numeric and may be
  positive, zero, or negative.

  Attributes default to `%{}` per spec L1133-L1137 *"MUST
  be structured to accept a variable number of attributes,
  including none"*.

  Instrumentation authors should call `enabled?/2` before
  each `add/3` to avoid expensive computation when the
  instrument is disabled (spec L493-L495 — the enabled
  state is not static).

  Delegates to `Otel.API.Metrics.Meter.record/3` — both
  UpDownCounter.add and the synchronous siblings share a
  single Meter dispatch per
  `docs/decisions/synchronous-instruments.md`.
  """
  @spec add(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def add(instrument, value, attributes \\ %{}) do
    Otel.API.Metrics.Meter.record(instrument, value, attributes)
  end

  @doc """
  **OTel API SHOULD** — "Enabled" (`metrics/api.md`
  §General operations — Enabled, L479-L495).

  Returns whether the instrument is enabled. Per spec
  L493-L495 the returned value is **not static** — it can
  change over time as configuration or sampling state
  evolves. Instrumentation authors SHOULD call this each
  time before recording to have the most up-to-date
  response.

  Spec L485-L487: no required parameters today; the API is
  structured to accept future additions via a keyword list.

  Delegates to `Otel.API.Metrics.Meter.enabled?/2`.
  """
  @spec enabled?(
          instrument :: Otel.API.Metrics.Instrument.t(),
          opts :: Otel.API.Metrics.Instrument.enabled_opts()
        ) :: boolean()
  def enabled?(instrument, opts \\ []) do
    Otel.API.Metrics.Meter.enabled?(instrument, opts)
  end
end
