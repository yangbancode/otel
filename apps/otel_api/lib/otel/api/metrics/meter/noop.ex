defmodule Otel.API.Metrics.Meter.Noop do
  @moduledoc """
  No-op Meter implementation (OTel `metrics/noop.md` §Meter,
  Status: **Stable**, L84-L266).

  Implements the `Otel.API.Metrics.Meter` behaviour with the
  minimum work required by spec: instrument creation returns
  an `Otel.API.Metrics.Instrument` struct populated with
  identifying fields and a back-reference to this module;
  recording operations return `:ok`; callback registration
  returns an opaque `{Noop, :noop}` handle; unregistration
  returns `:ok`; `enabled?/2` returns `false`.

  Activated automatically by `Otel.API.Metrics.MeterProvider`
  when no SDK is installed (default fallback
  `{Otel.API.Metrics.Meter.Noop, []}`).

  ## Noop MUSTs from `metrics/noop.md`

  The following invariants hold for this module:

  - **No state** (L86-L88) — no module attributes, no
    process state
  - **No errors or logs** (L90-L91) — every function
    returns a well-formed value; no Logger calls
  - **Safe for concurrent use** (L93) — stateless
  - **Accept all creation params without validation**
    (L103-L107, L117-L121, L131-L135, L145-L149,
    L160-L164, L175-L179) — `build/4` stores whatever the
    caller provides
  - **No callback retention** (L149, L164, L179) — the
    `/5` arities of async creation capture `_callback` and
    `_callback_args` with `_` prefixes; neither is stored
    on the returned instrument
  - **No observation retention** (L240, L253, L266) — the
    Noop has no callback-evaluation path, so there is
    nothing to retain

  `noop.md` L95-L179 enumerates Counter, UpDownCounter,
  Histogram, Async Counter, Async UpDownCounter, and Async
  Gauge. Sync Gauge was added to `api.md` later and
  `noop.md` has not yet been updated; `create_gauge/3`
  follows the same pattern as the other `create_*/3`
  functions and is covered by the general §Meter
  invariants (L86-L93).

  ## Divergences from opentelemetry-erlang

  `opentelemetry-erlang`'s `otel_meter_noop.erl` diverges
  in four places. All are spec-aligned:

  1. **Creation API shape** — erlang exposes a single
     generic `create_instrument/4,6` taking `Kind` as a
     parameter; we expose kind-specific callbacks
     (`create_counter/3`, `create_observable_gauge/5`,
     etc.) matching the `Otel.API.Metrics.Meter`
     behaviour.
  2. **`register_callback` return value** — erlang returns
     `ok`. We return `{__MODULE__, :noop}` as the
     canonical registration handle per
     `docs/decisions/asynchronous-instruments-and-callbacks.md`
     — keeps the shape consistent with the SDK-installed
     path, so `unregister_callback/1` has a uniform input.
  3. **`unregister_callback/1`** — erlang has no such
     function. We implement it per spec `api.md`
     L419-L420 MUST (*"user MUST be able to undo
     registration of the specific callback"*).
  4. **`enabled?/2`** — erlang has no such function. We
     implement it per spec `api.md` L475-L495 SHOULD and
     return `false` — signals to instrumentation authors
     that recording paths can be skipped while the Noop
     is active.

  ## Defensive `||` fallbacks in `build/4`

  Optional `opts` fields are coerced through `||` so the
  returned `Instrument` struct has well-formed values
  even when the caller passes an explicit `nil`:

  - `unit`, `description` → `|| ""`
  - `advisory` → `|| []`

  This aligns with `noop.md` L81 *"MUST accept these
  parameters. However, the MeterProvider MUST NOT
  validate any argument it receives"* — acceptance over
  validation for the explicitly-optional fields.

  `name` is a required positional parameter
  (`String.t()`) and is passed through unchanged; per
  `.claude/rules/code-conventions.md` §Happy-path only,
  the caller supplies a valid string and we do not
  defend against type violations at runtime.

  ## Public API

  | Function | Role |
  |---|---|
  | `create_counter/3` | **OTel API MUST** (`noop.md` §Counter Creation, L95-L107) |
  | `create_updown_counter/3` | **OTel API MUST** (`noop.md` §UpDownCounter Creation, L109-L121) |
  | `create_histogram/3` | **OTel API MUST** (`noop.md` §Histogram Creation, L123-L135) |
  | `create_gauge/3` | **OTel API MUST** (`api.md` §Gauge; `noop.md` general §Meter invariants) |
  | `create_observable_counter/3,5` | **OTel API MUST** (`noop.md` §Async Counter Creation, L137-L149) |
  | `create_observable_updown_counter/3,5` | **OTel API MUST** (`noop.md` §Async UpDownCounter Creation, L151-L164) |
  | `create_observable_gauge/3,5` | **OTel API MUST** (`noop.md` §Async Gauge Creation, L166-L179) |
  | `record/3` | **OTel API MUST** (`noop.md` §Counter Add / §UpDownCounter Add / §Histogram Record / §Gauge Record, L196-L227) |
  | `register_callback/5` | **OTel API MUST** (`api.md` L408-L410 creation with callbacks) |
  | `unregister_callback/1` | **OTel API MUST** (`api.md` L419-L420 undo registration) |
  | `enabled?/2` | **OTel API SHOULD** (`api.md` §Enabled, L475-L495) |

  ## References

  - OTel Metrics Noop: `opentelemetry-specification/specification/metrics/noop.md`
  - OTel Metrics API §Asynchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L350-L472
  - OTel Metrics API §Enabled: `opentelemetry-specification/specification/metrics/api.md` L475-L495
  - Decision: `docs/decisions/asynchronous-instruments-and-callbacks.md`
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api_experimental/src/otel_meter_noop.erl`
  """

  use Otel.API.Common.Types

  @behaviour Otel.API.Metrics.Meter

  @doc """
  **OTel API MUST** — No-op Counter Creation (`noop.md`
  §Counter Creation, L95-L107).

  Returns an `Otel.API.Metrics.Instrument` struct with
  `kind: :counter`. No validation (L106-L107).
  """
  @impl true
  @spec create_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_counter(meter, name, opts), do: build(meter, name, :counter, opts)

  @doc """
  **OTel API MUST** — No-op UpDownCounter Creation
  (`noop.md` §UpDownCounter Creation, L109-L121).

  Returns an `Otel.API.Metrics.Instrument` struct with
  `kind: :updown_counter`. No validation (L120-L121).
  """
  @impl true
  @spec create_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_updown_counter(meter, name, opts), do: build(meter, name, :updown_counter, opts)

  @doc """
  **OTel API MUST** — No-op Histogram Creation (`noop.md`
  §Histogram Creation, L123-L135).

  Returns an `Otel.API.Metrics.Instrument` struct with
  `kind: :histogram`. No validation (L134-L135).
  """
  @impl true
  @spec create_histogram(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_histogram(meter, name, opts), do: build(meter, name, :histogram, opts)

  @doc """
  **OTel API MUST** — No-op Gauge Creation (`api.md`
  §Gauge L828-L916; `noop.md` §Meter general invariants
  L86-L93).

  Returns an `Otel.API.Metrics.Instrument` struct with
  `kind: :gauge`. Sync Gauge is not explicitly enumerated
  in `noop.md` (the dedicated Noop spec predates the sync
  Gauge addition to `api.md`); the general §Meter
  invariants — no state, no errors/logs, no validation —
  apply.
  """
  @impl true
  @spec create_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_gauge(meter, name, opts), do: build(meter, name, :gauge, opts)

  @doc """
  **OTel API MUST** — No-op Asynchronous Counter Creation
  without inline callback (`noop.md` §Async Counter
  Creation, L137-L149).
  """
  @impl true
  @spec create_observable_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter(meter, name, opts),
    do: build(meter, name, :observable_counter, opts)

  @doc """
  **OTel API MUST** — No-op Asynchronous Counter Creation
  with inline callback (`noop.md` §Async Counter Creation,
  L137-L149).

  Per spec L149 *"MUST NOT hold any reference to the
  passed callbacks"* — `_callback` and `_callback_args`
  are captured with `_` prefixes and discarded; neither is
  stored on the returned instrument.
  """
  @impl true
  @spec create_observable_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter(meter, name, _callback, _callback_args, opts),
    do: build(meter, name, :observable_counter, opts)

  @doc """
  **OTel API MUST** — No-op Asynchronous UpDownCounter
  Creation without inline callback (`noop.md` §Async
  UpDownCounter Creation, L151-L164).
  """
  @impl true
  @spec create_observable_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter(meter, name, opts),
    do: build(meter, name, :observable_updown_counter, opts)

  @doc """
  **OTel API MUST** — No-op Asynchronous UpDownCounter
  Creation with inline callback (`noop.md` §Async
  UpDownCounter Creation, L151-L164).

  Per spec L164 *"MUST NOT hold any reference to the
  passed callbacks"* — same contract as
  `create_observable_counter/5`.
  """
  @impl true
  @spec create_observable_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter(meter, name, _callback, _callback_args, opts),
    do: build(meter, name, :observable_updown_counter, opts)

  @doc """
  **OTel API MUST** — No-op Asynchronous Gauge Creation
  without inline callback (`noop.md` §Async Gauge
  Creation, L166-L179).
  """
  @impl true
  @spec create_observable_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge(meter, name, opts),
    do: build(meter, name, :observable_gauge, opts)

  @doc """
  **OTel API MUST** — No-op Asynchronous Gauge Creation
  with inline callback (`noop.md` §Async Gauge Creation,
  L166-L179).

  Per spec L179 *"MUST NOT hold any reference to the
  passed callbacks"* — same contract as
  `create_observable_counter/5`.
  """
  @impl true
  @spec create_observable_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge(meter, name, _callback, _callback_args, opts),
    do: build(meter, name, :observable_gauge, opts)

  @doc """
  **OTel API MUST** — No-op Add / Record (`noop.md`
  §Counter Add L196-L200, §UpDownCounter Add L210-L214,
  §Histogram Record L223-L227, and — by general §Meter
  invariants — §Gauge Record).

  Returns `:ok` without validating or retaining any state
  about the arguments received (L199-L200, L213-L214,
  L226-L227).
  """
  @impl true
  @spec record(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def record(_instrument, _value, _attributes), do: :ok

  @doc """
  **OTel API MUST** — No-op callback registration
  (`api.md` §Asynchronous Instrument API — callback
  registration, L408-L420).

  Returns `{__MODULE__, :noop}` as the registration
  handle, per
  `docs/decisions/asynchronous-instruments-and-callbacks.md`.
  `_callback` and `_callback_args` are discarded per the
  Noop no-retention invariant.
  """
  @impl true
  @spec register_callback(
          meter :: Otel.API.Metrics.Meter.t(),
          instruments :: [Otel.API.Metrics.Instrument.t()],
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.register_callback_opts()
        ) :: Otel.API.Metrics.Meter.registration()
  def register_callback(_meter, _instruments, _callback, _callback_args, _opts),
    do: {__MODULE__, :noop}

  @doc """
  **OTel API MUST** — No-op callback unregistration
  (`api.md` L419-L420 *"user MUST be able to undo
  registration of the specific callback"*).

  Accepts the opaque state from any prior
  `register_callback/5` call and returns `:ok` — there is
  nothing to undo because nothing was retained.
  """
  @impl true
  @spec unregister_callback(state :: term()) :: :ok
  def unregister_callback(_state), do: :ok

  @doc """
  **OTel API SHOULD** — Enabled (`api.md` §General
  operations — Enabled, L475-L495).

  Always returns `false` — signals to instrumentation
  authors that no recording will occur while the Noop is
  active, so expensive measurement computation can be
  skipped.
  """
  @impl true
  @spec enabled?(
          instrument :: Otel.API.Metrics.Instrument.t(),
          opts :: Otel.API.Metrics.Instrument.enabled_opts()
        ) :: boolean()
  def enabled?(_instrument, _opts), do: false

  @spec build(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          kind :: Otel.API.Metrics.Instrument.kind(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  defp build(meter, name, kind, opts) do
    %Otel.API.Metrics.Instrument{
      meter: meter,
      name: name,
      kind: kind,
      unit: Keyword.get(opts, :unit) || "",
      description: Keyword.get(opts, :description) || "",
      advisory: Keyword.get(opts, :advisory) || []
    }
  end
end
