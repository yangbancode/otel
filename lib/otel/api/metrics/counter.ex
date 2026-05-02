defmodule Otel.API.Metrics.Counter do
  @moduledoc """
  Synchronous Counter instrument facade (OTel
  `metrics/api.md` §Counter, Status: **Stable**, L497-L598).

  A Counter supports monotonically increasing non-negative
  increments recorded synchronously at the call site (spec
  L499-L500). Example uses: bytes received, requests
  completed, accounts created, HTTP 5xx error counts (spec
  L504-L508).

  Created exclusively through a `Meter` per spec L512
  *"MUST NOT be any API for creating a Counter other than
  with a Meter"*.

  ## Non-negative value contract

  Per spec L561-L564, the increment value is **expected to
  be non-negative**. The API:

  - SHOULD be documented to communicate the non-negative
    expectation (satisfied here)
  - SHOULD NOT validate — validation is the SDK's
    responsibility

  A negative value passed to `add/3` will be accepted at
  the API boundary and forwarded to the SDK, which decides
  how to handle it. If the domain supports bidirectional
  motion, use `Otel.API.Metrics.UpDownCounter` instead.

  ## BEAM representation

  `opentelemetry-erlang` implements this as a `defmacro`
  that resolves the meter implicitly via
  `opentelemetry_experimental:get_meter/1` at expansion
  time and injects `OpenTelemetry.Ctx.get_current()` into
  `:otel_counter.add/5` (`lib/open_telemetry/counter.ex`).
  We take a different path:

  - plain `def` with an explicit `Meter.t()` handle —
    macro-free, Dialyzer-visible, consistent with the
    `Tracer` and `Meter` facades project-wide
  - no implicit context threaded through `add/3` —
    synchronous metric measurements are not
    context-associated at the API boundary; the SDK
    attaches context per `Otel.Ctx` if relevant

  Erlang also does not expose `enabled?/2` on sync
  instruments; we add it per spec L475-L477 (SHOULD
  provide) and spec L479-L495 (Enabled API).

  All functions are safe for concurrent use (spec
  L1351-L1352, §Concurrency §Instrument).

  ## Public API

  | Function | Role |
  |---|---|
  | `create/3` | **Application** (OTel API MUST) — Counter creation (L510-L542) |
  | `add/3` | **Application** (OTel API MUST) — Counter Add (L545-L598) |
  | `enabled?/2` | **Application** (OTel API SHOULD) — Enabled (L479-L495) |

  ## References

  - OTel Metrics API §Counter: `opentelemetry-specification/specification/metrics/api.md` L497-L598
  - OTel Metrics API §Synchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L302-L348
  - OTel Metrics API §General operations / Enabled: `opentelemetry-specification/specification/metrics/api.md` L473-L495
  - OTel Metrics API §Concurrency §Instrument: `opentelemetry-specification/specification/metrics/api.md` L1351-L1352
  """

  use Otel.Common.Types

  @doc """
  **Application** (OTel API MUST) — "Counter creation"
  (`metrics/api.md` §Counter creation, L510-L542).

  Creates the instrument handle via the given Meter. Per
  spec L512, there is no other API surface for creating a
  Counter.

  Options (per §Synchronous Instrument API L302-L348):

  - `:unit` — case-sensitive ASCII string, max 63 chars
  - `:description` — opaque string (BMP Plane 0), at least
    1023 chars supported
  - `:advisory` — advisory parameters

  Delegates to `Otel.API.Metrics.Meter.create_counter/3`.
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_counter(meter, name, opts)
  end

  @doc """
  **Application** (OTel API MUST) — "Add" (`metrics/api.md`
  §Counter operations — Add, L545-L598).

  Increments the Counter by `value`. Per spec L561-L564 the
  value is expected to be non-negative; the API does not
  validate (`SHOULD NOT validate` per spec — SDK's job).

  Attributes default to `%{}` per spec L565-L570 *"MUST be
  structured to accept a variable number of attributes,
  including none"*.

  Instrumentation authors should call `enabled?/2` before
  each `add/3` to avoid expensive computation when the
  instrument is disabled (spec L493-L495 — the enabled
  state is not static).

  Delegates to `Otel.API.Metrics.Meter.record/3` — both
  Counter.add and the synchronous siblings share a single
  Meter dispatch.
  """
  @spec add(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive_any()}
        ) :: :ok
  def add(instrument, value, attributes \\ %{}) do
    Otel.API.Metrics.Meter.record(instrument, value, attributes)
  end

  @doc """
  **Application** (OTel API SHOULD) — "Enabled"
  (`metrics/api.md` §General operations — Enabled, L479-L495).

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
