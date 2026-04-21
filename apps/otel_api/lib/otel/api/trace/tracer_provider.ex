defmodule Otel.API.Trace.TracerProvider do
  @moduledoc """
  Global TracerProvider registration and Tracer retrieval
  (OTel `trace/api.md` §TracerProvider, L88-L157).

  Holds the process-wide pointer to the installed
  TracerProvider implementation and caches the `Tracer`
  instances it returns. When no SDK is installed, all
  operations resolve to the no-op tracer
  (`Otel.API.Trace.Tracer.Noop`, matching the
  `{otel_tracer_noop, []}` fallback in
  `opentelemetry-erlang`).

  ## Storage

  Both the global provider pointer and the scope-keyed tracer
  cache live in `:persistent_term`. The tracer-cache pattern
  mirrors `opentelemetry-erlang` (`opentelemetry.erl` caches
  tracers in `persistent_term` keyed by scope components). The
  global-provider pointer itself **diverges** — erlang uses a
  registered gen_server name reached via `gen_server:call/2`
  (`otel_tracer_provider.erl`), while we read a
  `persistent_term` slot directly to avoid the round-trip on
  the hot path.

  All functions are safe for concurrent use (spec L842).

  ## Public API

  | Function | Role |
  |---|---|
  | `get_tracer/1` | **OTel API MUST** (Get a Tracer, L107-L157) |
  | `get_tracer/2` (callback) | Internal dispatch contract (API ↔ SDK) |
  | `get_provider/0` | **Local helper** — introspection of current global provider |
  | `set_provider/1` | **Local helper** — SDK installation hook |

  ## References

  - OTel Trace API §TracerProvider: `opentelemetry-specification/specification/trace/api.md` L88-L157, L842
  - Reference impl (tracer cache): `opentelemetry-erlang/apps/opentelemetry_api/src/opentelemetry.erl`
  - Reference impl (global provider): `opentelemetry-erlang/apps/opentelemetry_api/src/otel_tracer_provider.erl`
  """

  @default_tracer {Otel.API.Trace.Tracer.Noop, []}

  @global_key {__MODULE__, :global}
  @tracer_key_prefix {__MODULE__, :tracer}

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

  @doc """
  Dispatch callback invoked by `get_tracer/1` on cache miss.

  Implementations receive the opaque `state` they registered
  via `set_provider/1` along with the requested instrumentation
  scope, and return the Tracer to cache. Not part of the OTel
  spec — this is the internal dispatch contract between the
  API and SDK layers.
  """
  @callback get_tracer(
              state :: term(),
              instrumentation_scope :: Otel.API.InstrumentationScope.t()
            ) :: Otel.API.Trace.Tracer.t()

  @doc """
  **OTel API MUST** — "Get a Tracer" (`trace/api.md` L107-L157).

  Returns a Tracer for the given instrumentation scope. On
  cache miss delegates to the registered provider's
  `get_tracer/2` callback, or returns the noop tracer when no
  provider is installed (spec L120-121: invalid or unresolved
  scope MUST still yield a working Tracer rather than crash).
  Subsequent calls with an equal scope return the cached
  tracer.
  """
  @spec get_tracer(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Trace.Tracer.t()
  def get_tracer(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    key = {@tracer_key_prefix, instrumentation_scope}

    case :persistent_term.get(key, nil) do
      nil ->
        tracer = fetch_or_default(instrumentation_scope)
        :persistent_term.put(key, tracer)
        tracer

      tracer ->
        tracer
    end
  end

  @doc """
  **Local helper** — introspection of the current global
  TracerProvider.

  Returns `nil` if no provider is registered.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  **Local helper** — SDK installation hook.

  Registers the given `{module, state}` as the global
  TracerProvider. The SDK TracerProvider calls this from its
  `init/1` with `{__MODULE__, server_ref}`; `module` must
  implement the `Otel.API.Trace.TracerProvider` behaviour.
  """
  @spec set_provider(provider :: t()) :: :ok
  def set_provider({module, _state} = provider) when is_atom(module) do
    :persistent_term.put(@global_key, provider)
    :ok
  end

  @spec fetch_or_default(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Trace.Tracer.t()
  defp fetch_or_default(instrumentation_scope) do
    case get_provider() do
      nil ->
        @default_tracer

      {module, state} ->
        module.get_tracer(state, instrumentation_scope)
    end
  end
end
