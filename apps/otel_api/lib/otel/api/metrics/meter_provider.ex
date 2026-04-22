defmodule Otel.API.Metrics.MeterProvider do
  @moduledoc """
  Global MeterProvider registration and Meter retrieval
  (OTel `metrics/api.md` §MeterProvider, Status: **Stable**,
  L106-L155).

  Holds the process-wide pointer to the installed
  MeterProvider implementation and caches the `Meter`
  instances it returns. When no SDK is installed, all
  operations resolve to the no-op meter
  (`Otel.API.Metrics.Meter.Noop`).

  ## Storage

  Both the global provider pointer and the scope-keyed meter
  cache live in `:persistent_term`. The dispatch pattern
  (`{dispatcher_module, state}` tuple + `get_meter/2`
  callback) is shared across Trace, Metrics, and Logs — see
  `docs/decisions/provider-dispatch.md`.

  `opentelemetry-erlang` diverges in three places:

  1. **Dispatch mechanism** — erlang's
     `otel_meter_provider.erl` calls `gen_server:call/2`
     directly on every `get_meter/1` invocation, wrapping
     it in `catch exit:{noproc, _} -> {otel_meter_noop,
     []}`. We read a `persistent_term` slot (for the
     provider) and a second `persistent_term` key (for
     each scope-keyed Meter) directly — the hot path never
     hits a process round-trip.
  2. **Caching** — erlang has no API-layer cache; each
     `get_meter/1` invokes the SDK gen_server. We cache per
     scope, so repeated lookups with equal scope structs
     return the same Meter handle without re-dispatch.
  3. **Surface** — erlang exposes `resource/0,1` and
     `force_flush/0,1` on the MeterProvider module. Those
     are SDK-level concerns in our design; the API surface
     is trimmed to spec-required operations.

  All functions are safe for concurrent use (spec
  L1345-L1346).

  ## Public API

  | Function | Role |
  |---|---|
  | `get_meter/0,1` | **OTel API MUST** (Get a Meter, L120-L155) |
  | `get_meter/2` (callback) | Internal dispatch contract (API ↔ SDK) |
  | `get_provider/0` | **Local helper** — introspection of current global provider |
  | `set_provider/1` | **Local helper** — SDK installation hook |

  ## References

  - OTel Metrics API §MeterProvider: `opentelemetry-specification/specification/metrics/api.md` L106-L155
  - OTel Metrics API §Concurrency: `opentelemetry-specification/specification/metrics/api.md` L1345-L1346
  - Dispatch pattern: `docs/decisions/provider-dispatch.md`
  - Reference impl (raw `gen_server:call`): `opentelemetry-erlang/apps/opentelemetry_api_experimental/src/otel_meter_provider.erl`
  """

  @default_meter {Otel.API.Metrics.Meter.Noop, []}

  @global_key {__MODULE__, :global}
  @meter_key_prefix {__MODULE__, :meter}

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

  @doc """
  Dispatch callback invoked by `get_meter/1` on cache miss.

  Implementations receive the opaque `state` they registered
  via `set_provider/1` along with the requested
  instrumentation scope, and return the Meter to cache. Not
  part of the OTel spec — this is the internal dispatch
  contract between the API and SDK layers.
  """
  @callback get_meter(
              state :: term(),
              instrumentation_scope :: Otel.API.InstrumentationScope.t()
            ) :: Otel.API.Metrics.Meter.t()

  @doc """
  **OTel API MUST** — "Get a Meter" (`metrics/api.md`
  L120-L155).

  Returns a Meter for the given instrumentation scope. On
  cache miss delegates to the registered provider's
  `get_meter/2` callback, or returns the noop meter when no
  provider is installed. Subsequent calls with an equal
  scope return the cached meter.

  The full `InstrumentationScope` struct (name, version,
  schema_url, attributes — spec L124-L151) is the cache
  key, so "identical" and "distinct" meters (L153-L155) are
  distinguished automatically by map equality.

  Without arguments, uses a default empty scope.
  """
  @spec get_meter(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Metrics.Meter.t()
  def get_meter(instrumentation_scope \\ %Otel.API.InstrumentationScope{})

  def get_meter(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    key = {@meter_key_prefix, instrumentation_scope}

    case :persistent_term.get(key, nil) do
      nil ->
        meter = fetch_or_default(instrumentation_scope)
        :persistent_term.put(key, meter)
        meter

      meter ->
        meter
    end
  end

  @doc """
  **Local helper** — introspection of the current global
  MeterProvider.

  Returns `nil` if no provider is registered.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  **Local helper** — SDK installation hook.

  Registers the given `{module, state}` as the global
  MeterProvider. The SDK MeterProvider calls this from its
  `init/1` with `{__MODULE__, server_ref}`; `module` must
  implement the `Otel.API.Metrics.MeterProvider` behaviour.

  To clear the registration (e.g. in tests), use
  `:persistent_term.erase/1` directly — see
  `docs/decisions/provider-dispatch.md`.
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
