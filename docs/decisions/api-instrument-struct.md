# API Instrument Struct (Unified)

## Question

How do we represent a Metrics Instrument on BEAM? As a name-keyed
concept routed through the Meter, or as an explicit handle struct
returned to the user? And do we need separate API-layer and SDK-layer
types, or a single struct shared across both?

## Decision

### Single `Otel.API.Metrics.Instrument` struct

One struct, defined in `apps/otel_api/lib/otel/api/metrics/instrument.ex`,
shared by both API and SDK layers. This struct is:

- the return value of every `Meter.create_*` function (sync and async),
- the argument every synchronous recording function accepts
  (`Counter.add/3`, `Histogram.record/3`, `Gauge.record/3`,
  `UpDownCounter.add/3`),
- the element type of the instrument list passed to
  `Meter.register_callback/5`,
- the value the SDK stores in its instruments ETS table.

```elixir
defmodule Otel.API.Metrics.Instrument do
  @type kind ::
          :counter | :histogram | :gauge | :updown_counter
          | :observable_counter | :observable_gauge | :observable_updown_counter

  @type temporality :: :cumulative | :delta

  @type t :: %__MODULE__{
    meter:       Otel.API.Metrics.Meter.t() | nil,
    name:        String.t(),
    kind:        kind(),
    unit:        String.t(),
    description: String.t(),
    advisory:    keyword(),
    scope:       Otel.API.InstrumentationScope.t()
  }

  defstruct meter: nil, name: "", kind: :counter, unit: "",
            description: "", advisory: [],
            scope: %Otel.API.InstrumentationScope{}
end
```

The `meter` field carries the `{module, config}` dispatcher so the
instrument is a self-sufficient handle — `Counter.add(instrument, v, a)`
resolves the SDK module from `instrument.meter` with no auxiliary
lookup.

### Why a single struct (not API handle + SDK record)

The prior plan had two structs: an API-layer `Otel.API.Metrics.Instrument`
(handle) plus an SDK-layer `Otel.SDK.Metrics.Instrument` (ETS record).
Before committing we checked both principles and walked away from the
split:

**Spec.** `api.md` L191 states *"Instruments are identified by the
`name`, `kind`, `unit`, and `description`"* — one concept, not two.
Spec is silent on language-level module structure; two structs is not
a Spec requirement. Erlang's reference implementation defines a single
`#instrument{}` record in its API header (`apps/opentelemetry_api_experimental/
include/otel_metrics.hrl:3-12`) that the SDK shares — same direction.

**API doesn't know SDK.** The single-struct layout keeps this intact:

| Check | Two structs | Single struct |
|---|---|---|
| API module imports SDK module | no | no |
| API module calls GenServer/ETS | no | no |
| `otel_api`-only consumer works | yes (Noop) | yes (Noop) |
| Spec concept "one Instrument" | split | preserved |
| SDK → API coupling (struct store) | converts at boundary | stores API struct directly |

The one real concession is that `api.md` and `sdk.md` split responsibility
across documents. Functions like `temporality/1`, `conflict_type/2` are
specified in `sdk.md`. Consolidating them on the
`Otel.API.Metrics.Instrument` module puts sdk.md logic physically inside
the `Otel.API.*` namespace. This is a mild conceptual leak, not a
technical one — these functions are stateless pure pattern matches with
no runtime coupling to SDK state, and Erlang places the same helpers on
its API-layer `otel_instrument` module for the same reason.

### All Instrument helpers live on `Otel.API.Metrics.Instrument`

No separate SDK helper module. The following functions sit alongside
the struct definition:

- `downcased_name/1` — case-insensitive comparison key
- `temporality/1`, `default_temporality_mapping/0` — kind → temporality (sdk.md)
- `identical?/2`, `conflict_type/2` — duplicate detection (sdk.md)
- `monotonic?/1` — aggregation hint (sdk.md)

We rejected `@behaviour` here: these functions have exactly one
implementation, no pluggable dispatch, and the spec does not leave
their behaviour open. `@behaviour` fits Meter / Sampler / Processor /
Exporter where multiple implementations coexist; it does not fit pure
data transformations. Wrapping them in `@callback` would add ceremony
without runtime benefit.

### API shape changes

Creation returns an Instrument:

```elixir
counter = Otel.API.Metrics.Counter.create(meter, "http.requests", unit: "1")
# counter :: %Otel.API.Metrics.Instrument{kind: :counter, meter: {...}, ...}
```

Recording takes the Instrument (no meter / no name argument):

```elixir
Otel.API.Metrics.Counter.add(counter, 1, %{"route" => "/foo"})
Otel.API.Metrics.Histogram.record(histogram, 42, %{})
Otel.API.Metrics.Gauge.record(gauge, 65, %{})
Otel.API.Metrics.UpDownCounter.add(updown, -1, %{})
```

Observable creation also returns an Instrument; the callback attachment
is unchanged in shape. `register_callback` accepts a list of
`Otel.API.Metrics.Instrument.t()` (no typespec widening).

`enabled?` narrows to the instrument:

```elixir
Otel.API.Metrics.Counter.enabled?(counter, opts \\ [])
```

The previous `Meter.enabled?(meter, instrument_name: "...")` pattern is
gone — the instrument carries both its meter and its name, so the
check is direct.

### Meter behaviour

Narrower after consolidation:

```elixir
@callback create_counter(meter, name, opts)            :: Instrument.t()
@callback create_histogram(meter, name, opts)          :: Instrument.t()
@callback create_gauge(meter, name, opts)              :: Instrument.t()
@callback create_updown_counter(meter, name, opts)     :: Instrument.t()

@callback create_observable_counter(meter, name, opts) :: Instrument.t()
@callback create_observable_counter(meter, name, callback, callback_args, opts)
  :: Instrument.t()
# (and the observable_gauge / observable_updown_counter variants)

@callback record(instrument, value, attributes) :: :ok
@callback enabled?(instrument, opts)            :: boolean()

@callback register_callback(meter, [Instrument.t()], callback, args, opts) :: term()
```

### Noop behaviour unchanged in contract

`Otel.API.Metrics.Meter.Noop.create_*` now returns an
`%Otel.API.Metrics.Instrument{}` with only identifying fields
populated — the `meter` field points at the Noop meter tuple so
downstream dispatch still works. `record/3` is a no-op, `enabled?/2`
returns `false`, `register_callback/5` returns `:ok`. No behavioral
change visible to consumers beyond the struct return type.

### SDK storage

`Otel.SDK.Metrics.Meter` stores the same `Otel.API.Metrics.Instrument`
struct in its `instruments_tab` ETS table and uses
`instrument.meter` / `instrument.name` / `instrument.scope` at the
recording site. No struct conversion crosses the layer boundary — one
shape in, one shape out.

The previous `Otel.SDK.Metrics.Instrument` module is removed; its
struct definition was duplicating identity fields and its helper
functions all move to `Otel.API.Metrics.Instrument`.

## Relationship to prior Decisions

Supersedes the "deferred — `Otel.API.Metrics.Instrument`" note in
[composite-entity-structs.md](composite-entity-structs.md) (L80-91).
That Decision explicitly parked this redesign; it lands here.

[synchronous-instruments.md](synchronous-instruments.md) and
[asynchronous-instruments-and-callbacks.md](asynchronous-instruments-and-callbacks.md)
describe the old name-keyed recording path
(`Counter.add(meter, name, value, attrs)`). Their compliance citations
remain correct; the call-shape tables in each will be updated to the
instrument-handle form alongside this PR.

[meter-instrument-registration-and-validation.md](meter-instrument-registration-and-validation.md)
documents ETS storage keyed by `{scope, downcased_name}` — that scheme
is preserved; only the struct stored under each key changes its
namespace.

## Relationship to opentelemetry-erlang

The reference implementation has `#instrument{module, meter, name,
description, kind, unit, temporality, callback, callback_args,
advisory_params}` in its API include file, shared by both layers. Our
struct matches that shape (with `scope` instead of pre-computed
`temporality`; temporality is derived via `temporality/1`).

Erlang's user-facing recording API, however, is still name-keyed
(`otel_counter:add(Ctx, Meter, Name, Number, Attrs)` →
`otel_meter:record/5`) — the instrument handle returned by `create` is
discarded at the call site. We diverge here and follow the Spec's
handle-based shape from `api.md` directly
(`exception_counter.add(1, attrs)` at L586;
`http_server_duration.Record(50, …)` at L817). This is closer to the
Spec's presentation and avoids an ETS lookup per record call.

## Modules

- `apps/otel_api/lib/otel/api/metrics/instrument.ex` — struct + all
  helpers (new)
- `apps/otel_api/lib/otel/api/metrics/meter.ex` — updated behaviour
- `apps/otel_api/lib/otel/api/metrics/meter/noop.ex` — returns structs
- `apps/otel_api/lib/otel/api/metrics/counter.ex`,
  `histogram.ex`, `gauge.ex`, `updown_counter.ex` — `(instrument, value, attrs)`
- `apps/otel_api/lib/otel/api/metrics/observable_counter.ex`,
  `observable_gauge.ex`, `observable_updown_counter.ex` — return `Instrument.t()`
- `apps/otel_sdk/lib/otel/sdk/metrics/meter.ex` — stores
  `Otel.API.Metrics.Instrument` in ETS; `record/3`, `enabled?/2` take
  instrument
- `apps/otel_sdk/lib/otel/sdk/metrics/instrument.ex` — **removed**

## Compliance

- [Metrics API](../compliance.md)
  * Instrument — L191, L194
  * Counter operations — L545, L586
  * Histogram operations — L781, L817
  * Gauge operations — L876
  * UpDownCounter operations — L1118
  * Asynchronous Instrument API — L357, L415, L419, L428, L430
  * Enabled (synchronous) — L475-495
- [Metrics SDK](../compliance.md)
  * Meter (Stable) — L872
  * Duplicate Instrument Registration — L912, L919, L923
  * Instrument Advisory Parameters — L985, L990, L996, L1009
  * Instrument Enabled — L1029, L1037
