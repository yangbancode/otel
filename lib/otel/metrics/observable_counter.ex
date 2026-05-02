defmodule Otel.Metrics.ObservableCounter do
  @moduledoc """
  Asynchronous Counter instrument facade (OTel
  `metrics/api.md` §Asynchronous Counter, Status: **Stable**,
  L599-L733).

  Reports monotonically increasing absolute value(s) when
  the instrument is being observed (spec L601-L603).
  Example uses: CPU time per thread/process/system, page
  fault counts (spec L607-L611).

  Per spec L631-L634, unlike `Counter.add/3,4` which takes
  the increment/delta, the callback reports the **absolute
  value** — the SDK derives the rate of change by
  differencing successive readings.

  Created exclusively through a `Meter` per spec L615
  *"MUST NOT be any API for creating an Asynchronous Counter
  other than with a Meter"*. Two creation styles:

  - `create/3` — create the instrument without callbacks;
    register them later via
    `Otel.Metrics.Meter.register_callback/5` (spec L415
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
  time (`lib/open_telemetry/observable_counter.ex`). We use
  plain `def` with an explicit `Meter.t()` handle as the
  first argument — a BEAM-Elixir idiom that keeps the call
  path macro-free and the handle inspectable. Consistent
  with the `Tracer` and `Meter` facade pattern throughout
  the project.

  All functions are safe for concurrent use (spec
  L1351-L1352, §Concurrency §Instrument).

  ## Public API

  | Function | Role |
  |---|---|
  | `create/3`, `create/5` | **Application** (OTel API MUST) — Asynchronous Counter creation (L613-L703) |

  ## References

  - OTel Metrics API §Asynchronous Counter: `opentelemetry-specification/specification/metrics/api.md` L599-L733
  - OTel Metrics API §Asynchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L350-L472
  - OTel Metrics API §Concurrency §Instrument: `opentelemetry-specification/specification/metrics/api.md` L1351-L1352
  """

  @doc """
  **Application** (OTel API MUST) — "Asynchronous Counter
  creation" without an inline callback (`metrics/api.md`
  §Asynchronous Counter creation, L613-L629).

  Creates the instrument handle; callbacks can be registered
  later via `Otel.Metrics.Meter.register_callback/5`
  (spec L415 SHOULD).

  Options (per §Instrument general characteristics):

  - `:unit` — case-sensitive ASCII string, max 63 chars
  - `:description` — opaque string (BMP Plane 0), at least
    1023 chars supported
  - `:advisory` — advisory parameters

  Delegates to
  `Otel.Metrics.Meter.create_observable_counter/3`.
  """
  @spec create(
          meter :: Otel.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.Metrics.Instrument.create_opts()
        ) :: Otel.Metrics.Instrument.t()
  def create(meter, name, opts \\ []) do
    Otel.Metrics.Meter.create_observable_counter(meter, name, opts)
  end

  @doc """
  **Application** (OTel API MUST) — "Asynchronous Counter
  creation" with an inline callback (`metrics/api.md`
  §Asynchronous Counter creation, L613-L703).

  Creates the instrument and permanently attaches
  `callback`. Per spec L446-L447 MUST, callbacks registered
  at creation time apply to the single instrument under
  construction.

  - `callback` — 1-arity function receiving `callback_args`;
    returns `[Otel.Metrics.Measurement.t()]` (spec
    L441-L442 MAY — list-return form)
  - `callback_args` — opaque state passed to the callback
    (spec L655-L658 SHOULD — API provides some way to pass
    state)
  - `opts` — same keys as `create/3`

  Delegates to
  `Otel.Metrics.Meter.create_observable_counter/5`.
  """
  @spec create(
          meter :: Otel.Metrics.Meter.t(),
          name :: String.t(),
          callback :: (term() -> [Otel.Metrics.Measurement.t()]),
          callback_args :: term(),
          opts :: Otel.Metrics.Instrument.create_opts()
        ) :: Otel.Metrics.Instrument.t()
  def create(meter, name, callback, callback_args, opts) do
    Otel.Metrics.Meter.create_observable_counter(meter, name, callback, callback_args, opts)
  end
end
