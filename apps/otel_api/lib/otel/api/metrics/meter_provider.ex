defmodule Otel.API.Metrics.MeterProvider do
  @moduledoc """
  Global MeterProvider registration and Meter retrieval
  (OTel `metrics/api.md` §MeterProvider, Status: **Stable**,
  L106-L155).

  Holds the process-wide pointer to the installed
  MeterProvider implementation. When no SDK is installed,
  all operations resolve to the no-op meter
  (`Otel.API.Metrics.Meter.Noop`).

  ## No API-level Meter cache

  `get_meter/1` does **not** cache the Meter it returns.
  Every call delegates to the registered provider's
  `get_meter/2` callback (or returns Noop if none). This
  avoids a bootstrap race: if an early `get_meter/1` is
  made before the SDK registers, a cached Noop would
  survive provider installation and silently drop every
  subsequent measurement.

  The spec's *"identical for identical parameters"*
  requirement (`metrics/api.md` L153-L155) is still
  satisfied because SDK implementations return
  structurally-equal Meter tuples for equal scopes, and
  the Noop case is trivially `{Noop, []}` on every call.

  Performance: the API is a straight `fetch_or_default`
  call per invocation. SDK implementations that care about
  Meter-instance reuse should cache internally on their
  own `get_meter/2` path.

  ## Storage

  The global provider pointer lives in `:persistent_term`.
  The dispatch pattern (`{dispatcher_module, state}` tuple
  + `get_meter/2` callback) is shared across Trace,
  Metrics, and Logs.

  `opentelemetry-erlang` diverges in two places:

  1. **Dispatch mechanism** — erlang's
     `otel_meter_provider.erl` calls `gen_server:call/2`
     directly on every `get_meter/1` invocation, wrapping
     it in `catch exit:{noproc, _} -> {otel_meter_noop,
     []}`. We read a `persistent_term` slot (for the
     provider) directly — the hot path never hits a
     process round-trip for provider lookup.
  2. **Surface** — erlang exposes `resource/0,1` and
     `force_flush/0,1` on the MeterProvider module. Those
     are SDK-level concerns in our design; the API surface
     is trimmed to spec-required operations.

  All functions are safe for concurrent use (spec
  L1345-L1346).

  ## Public API

  | Function | Role |
  |---|---|
  | `get_meter/0,1` | **Application** (OTel API MUST) — Get a Meter (L120-L155) |
  | `@callback get_meter/2` | **SDK** (OTel API MUST) — Dispatch callback (L120-L155) |
  | `get_provider/0` | **SDK** (installation hook) — access global provider (L110-L112) |
  | `set_provider/1` | **SDK** (installation hook) — register global provider (L110-L112) |

  ## References

  - OTel Metrics API §MeterProvider: `opentelemetry-specification/specification/metrics/api.md` L106-L155
  - OTel Metrics API §Concurrency: `opentelemetry-specification/specification/metrics/api.md` L1345-L1346
  - Reference impl (raw `gen_server:call`): `opentelemetry-erlang/apps/opentelemetry_api_experimental/src/otel_meter_provider.erl`
  """

  @default_meter {Otel.API.Metrics.Meter.Noop, []}

  @global_key {__MODULE__, :global}

  @typedoc """
  A `{dispatcher_module, state}` pair.

  The API layer treats the state as opaque; only
  `dispatcher_module` knows how to use it. This mirrors
  `Otel.API.Metrics.Meter.t/0` and keeps the API decoupled
  from SDK internals (GenServer, Registry, etc.).

  `dispatcher_module` MUST implement the
  `Otel.API.Metrics.MeterProvider` behaviour.
  """
  @type t :: {module(), term()}

  # --- Application dispatch ---

  @doc """
  **Application** (OTel API MUST) — "Get a Meter"
  (`metrics/api.md` L120-L155).

  Returns a Meter for the given instrumentation scope. Each
  call delegates to the registered provider's `get_meter/2`
  callback, or returns the noop meter when no provider is
  installed — no API-level cache, see the module's *"No
  API-level Meter cache"* section.

  The full `InstrumentationScope` struct (name, version,
  schema_url, attributes — spec L124-L151) is passed to the
  provider. Spec's "identical for identical parameters"
  (L153-L155) is satisfied by SDK-side structural equality.

  Without arguments, uses a default empty scope.
  """
  @spec get_meter(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Metrics.Meter.t()
  def get_meter(instrumentation_scope \\ %Otel.API.InstrumentationScope{})

  def get_meter(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    fetch_or_default(instrumentation_scope)
  end

  # --- SDK callbacks ---

  @doc """
  **SDK** (OTel API MUST) — Dispatch callback invoked by
  `get_meter/1` on cache miss.

  Implementations receive the opaque `state` they registered
  via `set_provider/1` along with the requested
  instrumentation scope, and return the Meter to cache. The
  `get_meter/2` shape is the API↔SDK dispatch contract for
  §"Get a Meter" (`metrics/api.md` L120-L155).
  """
  @callback get_meter(
              state :: term(),
              instrumentation_scope :: Otel.API.InstrumentationScope.t()
            ) :: Otel.API.Metrics.Meter.t()

  # --- SDK installation hooks ---

  @doc """
  **SDK** (installation hook) — access the global
  MeterProvider (`metrics/api.md` L110-L112).

  > *"the API SHOULD provide a way to set/register and
  > access a global default `MeterProvider`."*

  Returns the currently registered provider, or `nil` if
  none is registered.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  **SDK** (installation hook) — register the global
  MeterProvider (`metrics/api.md` L110-L112).

  > *"the API SHOULD provide a way to set/register and
  > access a global default `MeterProvider`."*

  Registers the given `{module, state}` as the global
  MeterProvider. The SDK MeterProvider calls this from its
  `init/1` with `{__MODULE__, server_ref}`; `module` must
  implement the `Otel.API.Metrics.MeterProvider` behaviour.

  To clear the registration (e.g. in tests), use
  `:persistent_term.erase/1` directly.
  """
  @spec set_provider(provider :: t()) :: :ok
  def set_provider({_module, _state} = provider) do
    :persistent_term.put(@global_key, provider)
    :ok
  end

  @spec fetch_or_default(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Metrics.Meter.t()
  defp fetch_or_default(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    case get_provider() do
      nil ->
        @default_meter

      {module, state} ->
        module.get_meter(state, instrumentation_scope)
    end
  end
end
