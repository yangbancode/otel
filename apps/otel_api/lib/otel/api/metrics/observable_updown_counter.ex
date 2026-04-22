defmodule Otel.API.Metrics.ObservableUpDownCounter do
  @moduledoc """
  Asynchronous UpDownCounter instrument facade (OTel
  `metrics/api.md` §Asynchronous UpDownCounter, Status:
  **Stable**, L1158-L1277).

  Reports additive value(s) that can increase or decrease
  when the instrument is being observed (spec L1160-L1164).
  Example uses: process heap size, approximate item count in
  a lock-free circular buffer (spec L1173-L1174).

  Per spec L1195-L1198, unlike `UpDownCounter.add/3,4` which
  takes the increment/delta, the callback reports the
  **absolute value** — the SDK derives the rate of change
  by differencing successive readings.

  Per spec L1166-L1169, use this when the value is additive
  but not monotonic. For monotonic values, use
  `ObservableCounter`; for non-additive values, use
  `ObservableGauge`.

  Created exclusively through a `Meter` per spec L1178
  *"MUST NOT be any API for creating an Asynchronous
  UpDownCounter other than with a Meter"*. Two creation
  styles per
  `docs/architecture/asynchronous-instruments-and-callbacks.md`:

  - `create/3` — create the instrument without callbacks;
    register them later via
    `Otel.API.Metrics.Meter.register_callback/5` (spec L415
    SHOULD — post-creation registration)
  - `create/5` — create with an inline callback
    permanently attached (spec L446-L447 MUST — callbacks
    registered at creation time apply to the single
    instrument under construction)

  Callback expectations (spec L428-L433, SHOULDs, not
  enforced at runtime):

  - reentrant safe
  - should not take an indefinite amount of time
  - no duplicate observations (same `attributes` across all
    callbacks)

  ## BEAM representation

  `opentelemetry-erlang` implements this as a `defmacro`
  that resolves the meter implicitly via
  `opentelemetry_experimental:get_meter/1` at expansion
  time (`lib/open_telemetry/observable_up_down_counter.ex`).
  We use plain `def` with an explicit `Meter.t()` handle as
  the first argument — a BEAM-Elixir idiom that keeps the
  call path macro-free and the handle inspectable.
  Consistent with the `Tracer` and `Meter` facade pattern
  throughout the project.

  All functions are safe for concurrent use (spec
  L1351-L1352, §Concurrency §Instrument).

  ## Public API

  | Function | Role |
  |---|---|
  | `create/3`, `create/5` | **OTel API MUST** (Asynchronous UpDownCounter creation, L1176-L1270) |

  ## References

  - OTel Metrics API §Asynchronous UpDownCounter: `opentelemetry-specification/specification/metrics/api.md` L1158-L1277
  - OTel Metrics API §Asynchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L350-L472
  - OTel Metrics API §Concurrency §Instrument: `opentelemetry-specification/specification/metrics/api.md` L1351-L1352
  - Decision: `docs/architecture/asynchronous-instruments-and-callbacks.md`
  """

  @doc """
  **OTel API MUST** — "Asynchronous UpDownCounter creation"
  without an inline callback (`metrics/api.md`
  §Asynchronous UpDownCounter creation, L1176-L1194).

  Creates the instrument handle; callbacks can be registered
  later via `Otel.API.Metrics.Meter.register_callback/5`
  (spec L415 SHOULD).

  Options (per §Instrument general characteristics):

  - `:unit` — case-sensitive ASCII string, max 63 chars
  - `:description` — opaque string (BMP Plane 0), at least
    1023 chars supported
  - `:advisory` — advisory parameters

  Delegates to
  `Otel.API.Metrics.Meter.create_observable_updown_counter/3`.
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_observable_updown_counter(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Asynchronous UpDownCounter creation"
  with an inline callback (`metrics/api.md` §Asynchronous
  UpDownCounter creation, L1176-L1270).

  Creates the instrument and permanently attaches
  `callback`. Per spec L446-L447 MUST, callbacks registered
  at creation time apply to the single instrument under
  construction.

  - `callback` — 1-arity function receiving `callback_args`;
    returns `[Otel.API.Metrics.Measurement.t()]` (spec
    L441-L442 MAY — list-return form)
  - `callback_args` — opaque state passed to the callback
    (spec L655-L658 SHOULD — API provides some way to pass
    state; cited on §Asynchronous Counter but applies
    generally across async instruments)
  - `opts` — same keys as `create/3`

  Delegates to
  `Otel.API.Metrics.Meter.create_observable_updown_counter/5`.
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create(meter, name, callback, callback_args, opts) do
    Otel.API.Metrics.Meter.create_observable_updown_counter(
      meter,
      name,
      callback,
      callback_args,
      opts
    )
  end
end
