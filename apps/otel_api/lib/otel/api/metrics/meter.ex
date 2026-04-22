defmodule Otel.API.Metrics.Meter do
  @moduledoc """
  `Meter` behaviour and dispatch facade (OTel `metrics/api.md`
  §Meter, Status: **Stable**, L157-L176).

  A Meter creates instruments. Per spec L161-L162 *"Meter
  SHOULD NOT be responsible for the configuration. This
  should be the responsibility of the MeterProvider
  instead"* — we honour this by keeping configuration
  (resource, views, etc.) in `Otel.API.Metrics.MeterProvider`
  and exposing no config-related functions on the Meter
  itself. Spec L166-L174 enumerates seven instruments the
  Meter MUST provide creation functions for; all seven are
  covered (`create_counter/3`, `create_histogram/3`,
  `create_gauge/3`, `create_updown_counter/3`, plus the
  three `create_observable_*` pairs).

  ## BEAM representation

  A Meter is represented as a `{dispatcher_module, state}`
  tuple — the same shape `Tracer` and `Logger` use and the
  canonical facade-dispatch form documented in
  `docs/decisions/provider-dispatch.md`. Callers obtain a
  Meter via `Otel.API.Metrics.MeterProvider.get_meter/1`
  rather than constructing the tuple directly; the
  `dispatcher_module` MUST implement this behaviour.

  All functions are safe for concurrent use (spec
  L1351-L1352, §Concurrency §Instrument).

  ## Divergences from opentelemetry-erlang

  `opentelemetry-erlang`'s `otel_meter.erl` diverges in
  seven places. All are spec-aligned or intentional
  API-surface trims:

  1. **Creation API shape** — erlang has generic
     `create_instrument/4,6(Kind)` callbacks taking the
     kind as a parameter; we expose one callback per
     instrument kind (10 callbacks total across `/3` and
     `/5` arities). Matches the facade-per-kind pattern
     (`Counter`, `Histogram`, `ObservableGauge`, …) that
     `docs/decisions/synchronous-instruments.md` and
     `docs/decisions/asynchronous-instruments-and-callbacks.md`
     describe.
  2. **`register_callback/5` signature** — erlang has
     `register_callback/4` (no `opts`, returns `ok`). We
     accept `opts` and return a `registration()` handle
     consumable by `unregister_callback/1`.
  3. **`unregister_callback/1` added** — erlang has no
     such function. Spec `api.md` L419-L420 MUST *"user
     MUST be able to undo registration of the specific
     callback"*; we implement it.
  4. **`enabled?/2` added** — erlang has no such function.
     Spec `api.md` L475-L495 SHOULD provides the
     instrument-enabled API; we implement it.
  5. **`record/3` without context** — erlang threads
     `Ctx` through `record/5`. Per
     `docs/decisions/synchronous-instruments.md`, our
     synchronous metric recording does not associate with
     context at the API boundary.
  6. **`scope/1` not exposed** — erlang returns the
     instrumentation scope from a Meter. We do not expose
     this; MeterProvider holds the scope, and the
     `{module, state}` tuple carries whatever the SDK
     needs. Not a spec MUST; API surface trim.
  7. **`lookup_instrument/2` not exposed** — erlang
     supports looking up an existing instrument by name.
     Not a spec operation; callers hold the struct handle
     returned by `create_*`. API surface trim.

  ## Public API

  | Function | Role |
  |---|---|
  | `create_counter/3` | **OTel API MUST** (Counter creation, `api.md` L510-L542) |
  | `create_histogram/3` | **OTel API MUST** (Histogram creation, `api.md` L746-L777) |
  | `create_gauge/3` | **OTel API MUST** (Gauge creation, `api.md` L852-L872) |
  | `create_updown_counter/3` | **OTel API MUST** (UpDownCounter creation, `api.md` L1084-L1115) |
  | `create_observable_counter/3,5` | **OTel API MUST** (Async Counter creation, `api.md` L613-L703) |
  | `create_observable_gauge/3,5` | **OTel API MUST** (Async Gauge creation, `api.md` L934-L1031) |
  | `create_observable_updown_counter/3,5` | **OTel API MUST** (Async UpDownCounter creation, `api.md` L1176-L1277) |
  | `record/3` | **OTel API MUST** (Counter Add / Histogram Record / Gauge Record / UpDownCounter Add dispatch) |
  | `register_callback/5` | **OTel API MUST** (callback creation, `api.md` L408-L410) |
  | `unregister_callback/1` | **OTel API MUST** (`api.md` L419-L420) |
  | `enabled?/2` | **OTel API SHOULD** (Enabled, `api.md` L475-L495) |

  Each dispatch function has a corresponding `@callback`
  of the same name and arity — the internal contract
  between this facade and the SDK-registered dispatcher
  module.

  ## References

  - OTel Metrics API §Meter: `opentelemetry-specification/specification/metrics/api.md` L157-L176
  - OTel Metrics API §Synchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L302-L348
  - OTel Metrics API §Asynchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L350-L472
  - OTel Metrics API §General operations / Enabled: `opentelemetry-specification/specification/metrics/api.md` L473-L495
  - OTel Metrics API §Concurrency §Instrument: `opentelemetry-specification/specification/metrics/api.md` L1351-L1352
  - Decision: `docs/decisions/synchronous-instruments.md`
  - Decision: `docs/decisions/asynchronous-instruments-and-callbacks.md`
  - Decision: `docs/decisions/provider-dispatch.md`
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api_experimental/src/otel_meter.erl`
  """

  use Otel.API.Common.Types

  @typedoc """
  A `{dispatcher_module, state}` pair.

  The API layer treats `state` as opaque; only
  `dispatcher_module` knows how to interpret it.
  `dispatcher_module` MUST implement the
  `Otel.API.Metrics.Meter` behaviour.

  Obtain a Meter via
  `Otel.API.Metrics.MeterProvider.get_meter/1` rather than
  constructing the tuple directly.
  """
  @type t :: {module(), term()}

  @typedoc """
  Handle returned by `register_callback/5`. Pass to
  `unregister_callback/1` to undo the registration.

  Structurally a `{dispatcher_module, state}` pair — the
  same shape as `t/0` — but distinct in role: `registration`
  identifies a callback registration rather than a Meter.
  The API layer treats `state` as opaque; callers should
  consume the handle exclusively through
  `unregister_callback/1` rather than destructuring it.

  Not declared `@opaque` because dispatcher implementations
  (e.g. `Otel.API.Metrics.Meter.Noop`, the SDK Meter) must
  construct the tuple directly — an `@opaque` type cannot
  be constructed from outside its defining module, which
  would require an extra factory function per the
  `{module, state}` dispatch idiom the project already uses
  unopaqued on `Tracer.t/0`, `Logger.t/0`, and `Meter.t/0`.
  """
  @type registration :: {module(), term()}

  # --- Synchronous Instruments (behaviour callbacks) ---

  @callback create_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_histogram(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_gauge(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_updown_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  # --- Asynchronous Instruments (behaviour callbacks) ---

  @callback create_observable_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_observable_counter(
              meter :: t(),
              name :: String.t(),
              callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_observable_gauge(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_observable_gauge(
              meter :: t(),
              name :: String.t(),
              callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_observable_updown_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  @callback create_observable_updown_counter(
              meter :: t(),
              name :: String.t(),
              callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  # --- Callback Registration (behaviour callbacks) ---

  # Callback return shape is spec-defined at `api.md`
  # L1302-L1303 *"The list (or tuple, etc.) returned by the
  # callback function contains `(Instrument, Measurement)`
  # pairs"* — combined with the L452-L453 MUST that
  # *"Idiomatic APIs for multiple-instrument Callbacks MUST
  # distinguish the instrument associated with each observed
  # Measurement value"*. The instrument tag is therefore a
  # spec-mandated part of the return shape.
  @callback register_callback(
              meter :: t(),
              instruments :: [Otel.API.Metrics.Instrument.t()],
              callback ::
                (term() ->
                   [{Otel.API.Metrics.Instrument.t(), Otel.API.Metrics.Measurement.t()}]),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.register_callback_opts()
            ) :: registration()

  @callback unregister_callback(state :: term()) :: :ok

  # --- Recording (behaviour callback) ---

  @callback record(
              instrument :: Otel.API.Metrics.Instrument.t(),
              value :: number(),
              attributes :: %{String.t() => primitive() | [primitive()]}
            ) :: :ok

  # --- Enabled (behaviour callback) ---

  @callback enabled?(
              instrument :: Otel.API.Metrics.Instrument.t(),
              opts :: Otel.API.Metrics.Instrument.enabled_opts()
            ) :: boolean()

  # --- Dispatch Functions ---

  @doc """
  **OTel API MUST** — "Counter creation" (`api.md`
  L510-L542). Dispatches to
  `dispatcher_module.create_counter/3`.
  """
  @spec create_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_counter({module, _} = meter, name, opts \\ []) do
    module.create_counter(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Histogram creation" (`api.md`
  L746-L777). Dispatches to
  `dispatcher_module.create_histogram/3`.
  """
  @spec create_histogram(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_histogram({module, _} = meter, name, opts \\ []) do
    module.create_histogram(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Gauge creation" (`api.md`
  L852-L872). Dispatches to
  `dispatcher_module.create_gauge/3`.
  """
  @spec create_gauge(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_gauge({module, _} = meter, name, opts \\ []) do
    module.create_gauge(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "UpDownCounter creation" (`api.md`
  L1084-L1115). Dispatches to
  `dispatcher_module.create_updown_counter/3`.
  """
  @spec create_updown_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_updown_counter({module, _} = meter, name, opts \\ []) do
    module.create_updown_counter(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Async Counter creation" without
  inline callback (`api.md` L613-L703). Dispatches to
  `dispatcher_module.create_observable_counter/3`.
  """
  @spec create_observable_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter({module, _} = meter, name, opts \\ []) do
    module.create_observable_counter(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Async Counter creation" with inline
  callback (`api.md` L613-L703). `callback` is a 1-arity
  function receiving `callback_args` and returning
  `[Measurement.t()]` per spec L441-L442 list-return form.
  Dispatches to
  `dispatcher_module.create_observable_counter/5`.
  """
  @spec create_observable_counter(
          meter :: t(),
          name :: String.t(),
          callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter({module, _} = meter, name, callback, callback_args, opts) do
    module.create_observable_counter(meter, name, callback, callback_args, opts)
  end

  @doc """
  **OTel API MUST** — "Async Gauge creation" without
  inline callback (`api.md` L934-L1031). Dispatches to
  `dispatcher_module.create_observable_gauge/3`.
  """
  @spec create_observable_gauge(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge({module, _} = meter, name, opts \\ []) do
    module.create_observable_gauge(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Async Gauge creation" with inline
  callback (`api.md` L934-L1031). Same callback contract as
  `create_observable_counter/5`.
  """
  @spec create_observable_gauge(
          meter :: t(),
          name :: String.t(),
          callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge({module, _} = meter, name, callback, callback_args, opts) do
    module.create_observable_gauge(meter, name, callback, callback_args, opts)
  end

  @doc """
  **OTel API MUST** — "Async UpDownCounter creation"
  without inline callback (`api.md` L1176-L1277).
  Dispatches to
  `dispatcher_module.create_observable_updown_counter/3`.
  """
  @spec create_observable_updown_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter({module, _} = meter, name, opts \\ []) do
    module.create_observable_updown_counter(meter, name, opts)
  end

  @doc """
  **OTel API MUST** — "Async UpDownCounter creation" with
  inline callback (`api.md` L1176-L1277). Same callback
  contract as `create_observable_counter/5`.
  """
  @spec create_observable_updown_counter(
          meter :: t(),
          name :: String.t(),
          callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter({module, _} = meter, name, callback, callback_args, opts) do
    module.create_observable_updown_counter(meter, name, callback, callback_args, opts)
  end

  @doc """
  **OTel API MUST** — Records a measurement for the given
  instrument.

  All synchronous recording paths route through here:

  - `Otel.API.Metrics.Counter.add/3` → Counter Add
    (`api.md` L545-L598)
  - `Otel.API.Metrics.UpDownCounter.add/3` → UpDownCounter
    Add (`api.md` L1118-L1156)
  - `Otel.API.Metrics.Histogram.record/3` → Histogram
    Record (`api.md` L781-L826)
  - `Otel.API.Metrics.Gauge.record/3` → Gauge Record
    (`api.md` L876-L915)

  The instrument carries its dispatcher module in its
  `meter` field; `record/3` pattern-matches on that and
  dispatches to `module.record/3`.
  """
  @spec record(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def record(
        %Otel.API.Metrics.Instrument{meter: {module, _}} = instrument,
        value,
        attributes \\ %{}
      ) do
    module.record(instrument, value, attributes)
  end

  @doc """
  **OTel API MUST** — Registers a callback for one or more
  asynchronous instruments (`api.md` L408-L410 MUST support
  callback creation).

  All `instruments` MUST belong to the same Meter (spec
  L455-L457). The callback is 1-arity and receives
  `callback_args`; its return is a list of
  `{Instrument, Measurement}` pairs per spec L1302-L1303
  and the L452-L453 MUST that *"multiple-instrument
  Callbacks MUST distinguish the instrument associated with
  each observed Measurement value"*.

  Returns a `registration()` handle — pass it to
  `unregister_callback/1` to undo the registration.
  """
  @spec register_callback(
          meter :: t(),
          instruments :: [Otel.API.Metrics.Instrument.t()],
          callback ::
            (term() -> [{Otel.API.Metrics.Instrument.t(), Otel.API.Metrics.Measurement.t()}]),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.register_callback_opts()
        ) :: registration()
  def register_callback({module, _} = meter, instruments, callback, callback_args, opts \\ []) do
    module.register_callback(meter, instruments, callback, callback_args, opts)
  end

  @doc """
  **OTel API MUST** — Undoes a prior `register_callback/5`
  registration (`api.md` L419-L420 *"user MUST be able to
  undo registration of the specific callback"*).

  `registration` is the opaque handle returned by
  `register_callback/5`. After this call the callback is no
  longer evaluated during collection.
  """
  @spec unregister_callback(registration :: registration()) :: :ok
  def unregister_callback({module, state}) do
    module.unregister_callback(state)
  end

  @doc """
  **OTel API SHOULD** — "Enabled" (`api.md` §General
  operations — Enabled, L475-L495).

  Returns whether the instrument is enabled. Per spec
  L493-L495 the returned value is **not static** — it can
  change over time as configuration or sampling state
  evolves. Instrumentation authors SHOULD call this each
  time before recording to have the most up-to-date
  response.
  """
  @spec enabled?(
          instrument :: Otel.API.Metrics.Instrument.t(),
          opts :: Otel.API.Metrics.Instrument.enabled_opts()
        ) :: boolean()
  def enabled?(%Otel.API.Metrics.Instrument{meter: {module, _}} = instrument, opts \\ []) do
    module.enabled?(instrument, opts)
  end
end
