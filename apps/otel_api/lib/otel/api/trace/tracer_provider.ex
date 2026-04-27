defmodule Otel.API.Trace.TracerProvider do
  @moduledoc """
  Global TracerProvider registration and Tracer retrieval
  (OTel `trace/api.md` §TracerProvider, L88-L157).

  Holds the process-wide pointer to the installed
  TracerProvider implementation. When no SDK is installed,
  all operations resolve to the no-op tracer
  (`Otel.API.Trace.Tracer.Noop`, matching the
  `{otel_tracer_noop, []}` fallback in
  `opentelemetry-erlang`).

  ## No API-level Tracer cache

  `get_tracer/1` does **not** cache the Tracer it returns.
  Every call delegates to the registered provider's
  `get_tracer/2` callback (or returns Noop if none). This
  avoids a bootstrap race: if an early `get_tracer/1` is
  made before the SDK registers, a cached Noop would
  survive provider installation and silently drop every
  subsequent span.

  The spec's *"identical for identical parameters"*
  requirement (`trace/api.md` L136-L140) is still satisfied
  because SDK implementations return structurally-equal
  Tracer tuples for equal scopes, and the Noop case is
  trivially `{Noop, []}` on every call.

  This is an **intentional divergence** from
  `opentelemetry-erlang` — its `opentelemetry.erl` caches
  tracers in `persistent_term` keyed by scope components.
  Our implementation trades that micro-optimisation for
  bootstrap-safety correctness. SDK implementations that
  care about Tracer-instance reuse should cache internally
  on their own `get_tracer/2` path.

  ## Storage

  The global provider pointer lives in `:persistent_term`.
  This **diverges** from erlang — its
  `otel_tracer_provider.erl` uses a registered gen_server
  reached via `gen_server:call/2`, while we read a
  `persistent_term` slot directly to avoid the round-trip
  on the hot path.

  All functions are safe for concurrent use (spec L842).

  ## Public API

  | Function | Role |
  |---|---|
  | `get_tracer/1` | **Application** (OTel API MUST) — Get a Tracer (L107-L157) |
  | `@callback get_tracer/2` | **SDK** (OTel API MUST) — Dispatch callback (L107-L157) |
  | `get_provider/0` | **SDK** (installation hook) — access global provider (L95-L97) |
  | `set_provider/1` | **SDK** (installation hook) — register global provider (L95-L97) |

  ## References

  - OTel Trace API §TracerProvider: `opentelemetry-specification/specification/trace/api.md` L88-L157, L842
  - Reference impl (tracer cache): `opentelemetry-erlang/apps/opentelemetry_api/src/opentelemetry.erl`
  - Reference impl (global provider): `opentelemetry-erlang/apps/opentelemetry_api/src/otel_tracer_provider.erl`
  """

  require Logger

  @default_tracer {Otel.API.Trace.Tracer.Noop, []}

  @global_key {__MODULE__, :global}

  @typedoc """
  A `{dispatcher_module, state}` pair.

  The API layer treats the state as opaque; only
  `dispatcher_module` knows how to use it. This mirrors
  `Otel.API.Trace.Tracer.t/0` and keeps the API decoupled from
  SDK internals (GenServer, Registry, etc.).

  `dispatcher_module` MUST implement the
  `Otel.API.Trace.TracerProvider` behaviour.
  """
  @type t :: {module(), term()}

  # --- Application dispatch ---

  @doc """
  **Application** (OTel API MUST) — "Get a Tracer" (`trace/api.md`
  L107-L157).

  Returns a Tracer for the given instrumentation scope. Each
  call delegates to the registered provider's `get_tracer/2`
  callback, or returns the noop tracer when no provider is
  installed (spec L120-121: invalid or unresolved scope
  MUST still yield a working Tracer rather than crash) —
  no API-level cache, see the module's *"No API-level
  Tracer cache"* section.
  """
  @spec get_tracer(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Trace.Tracer.t()
  def get_tracer(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    # Spec trace/api.md L125-L130 — *"In case an invalid name (null
    # or empty string) is specified, a working Tracer implementation
    # MUST be returned as a fallback rather than returning null or
    # throwing an exception, its `name` property SHOULD be set to an
    # empty string, and a message reporting that the specified value
    # is invalid SHOULD be logged."* The MUST (working Tracer) and
    # the original-value SHOULD are satisfied structurally — we
    # always return a Tracer (Noop or SDK) and never rewrite the
    # scope name. The warning SHOULD is enforced here.
    if instrumentation_scope.name == "" do
      Logger.warning(
        "Otel.API.Trace.TracerProvider: invalid Tracer name (empty string) — returning a working Tracer as fallback per spec L125-L130"
      )
    end

    case get_provider() do
      nil ->
        @default_tracer

      {module, state} ->
        module.get_tracer(state, instrumentation_scope)
    end
  end

  # --- SDK callbacks ---

  @doc """
  **SDK** (OTel API MUST) — Dispatch callback invoked by
  `get_tracer/1`.

  Implementations receive the opaque `state` they registered
  via `set_provider/1` along with the requested instrumentation
  scope, and return a Tracer. The `get_tracer/2` shape is the
  API↔SDK dispatch contract for §"Get a Tracer"
  (`trace/api.md` L107-L157).
  """
  @callback get_tracer(
              state :: term(),
              instrumentation_scope :: Otel.API.InstrumentationScope.t()
            ) :: Otel.API.Trace.Tracer.t()

  # --- SDK installation hooks ---

  @doc """
  **SDK** (installation hook) — access the global TracerProvider
  (`trace/api.md` L95-L97).

  > *"the API SHOULD provide a way to set/register and
  > access a global default `TracerProvider`."*

  Returns the currently registered provider, or `nil` if
  none is registered.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  **SDK** (installation hook) — register the global
  TracerProvider (`trace/api.md` L95-L97).

  > *"the API SHOULD provide a way to set/register and
  > access a global default `TracerProvider`."*

  Registers the given `{module, state}` as the global
  TracerProvider. The SDK TracerProvider calls this from its
  `init/1` with `{__MODULE__, server_ref}`; `module` must
  implement the `Otel.API.Trace.TracerProvider` behaviour.
  """
  @spec set_provider(provider :: t()) :: :ok
  def set_provider({_module, _state} = provider) do
    :persistent_term.put(@global_key, provider)
    :ok
  end
end
