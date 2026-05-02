defmodule Otel.Trace.TracerProvider do
  @moduledoc """
  TracerProvider — minikube hardcoded.

  Issues `%Otel.Trace.Tracer{}` structs and forwards
  `shutdown/1` / `force_flush/1` to the single hardcoded
  `Otel.Trace.SpanProcessor` (Batch). Configuration
  (`resource`, `span_limits`) is loaded once at boot via
  `init/0` and stored in `:persistent_term`; subsequent
  `get_tracer/1` calls are pure persistent_term reads.

  Not a GenServer — this module holds no process state. The
  three siblings under `Otel.Application` that *do* hold state
  are the BatchProcessor itself, `Otel.Trace.SpanStorage` (ETS
  owner), and the configured exporter.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/0` | **SDK** (boot hook) — seed `:persistent_term` (resource + spec-default span_limits) |
  | `get_tracer/1` | **Application** (OTel API MUST) — Get a Tracer (`trace/api.md` L107-L157) |
  | `shutdown/1` | **Application** (OTel API MUST) — Shutdown (`trace/sdk.md` §Shutdown) |
  | `force_flush/1` | **Application** (OTel API MUST) — ForceFlush (`trace/sdk.md` §ForceFlush) |
  | `resource/0`, `config/0` | **Application** (introspection) |
  | `shut_down?/0` | **SDK** — internal flag for `Tracer.enabled?/2` |

  ## References

  - OTel Trace SDK §Tracer Provider: `opentelemetry-specification/specification/trace/sdk.md` §TracerProvider
  - OTel Trace API §Tracer Provider: `opentelemetry-specification/specification/trace/api.md` §TracerProvider
  """

  require Logger

  @persistent_key {__MODULE__, :state}

  # Default timeout for `shutdown/1` and `force_flush/1`
  # (30000ms). Matches BatchSpanProcessor's `exportTimeoutMillis`
  # default.
  @default_shutdown_timeout_ms 30_000
  @default_force_flush_timeout_ms 30_000

  @typedoc "Internal provider state held in `:persistent_term`."
  @type state :: %{
          resource: Otel.Resource.t(),
          span_limits: Otel.Trace.SpanLimits.t(),
          shut_down: boolean()
        }

  @doc """
  **SDK** (boot hook) — Called once from `Otel.Application.start/2`
  to seed the `:persistent_term` slot. Idempotent — safe to call
  multiple times (each call replaces the slot wholesale).

  `span_limits` is hardcoded to the spec defaults; only the
  resource flows from the user's `config :otel, resource: %{...}`.
  """
  @spec init() :: :ok
  def init do
    :persistent_term.put(@persistent_key, %{
      resource: Otel.Resource.from_app_env(),
      span_limits: %Otel.Trace.SpanLimits{},
      shut_down: false
    })

    :ok
  end

  @doc """
  **Application** (OTel API MUST) — Get a Tracer
  (`trace/api.md` §Get a Tracer L107-L157).

  Returns a configured `%Otel.Trace.Tracer{}` struct stamped
  with the boot-time resource/limits and the caller's
  instrumentation scope. After `shutdown/1`, returns a
  degenerate Tracer (empty defaults).
  """
  @spec get_tracer(instrumentation_scope :: Otel.InstrumentationScope.t()) ::
          Otel.Trace.Tracer.t()
  def get_tracer(%Otel.InstrumentationScope{} = instrumentation_scope) do
    state = state()

    if state.shut_down do
      %Otel.Trace.Tracer{}
    else
      warn_invalid_scope_name(instrumentation_scope)

      %Otel.Trace.Tracer{
        scope: instrumentation_scope,
        span_limits: state.span_limits
      }
    end
  end

  @doc """
  **Application** (OTel API MUST) — Shutdown
  (`trace/sdk.md` §Shutdown).

  Sets the shut-down flag in `:persistent_term` and forwards
  to `Otel.Trace.SpanProcessor.shutdown/1`. Subsequent calls
  return `{:error, :already_shutdown}`.
  """
  @spec shutdown(timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(timeout \\ @default_shutdown_timeout_ms) do
    case :persistent_term.get(@persistent_key, nil) do
      nil ->
        :ok

      %{shut_down: true} ->
        {:error, :already_shutdown}

      state ->
        :persistent_term.put(@persistent_key, %{state | shut_down: true})
        Otel.Trace.SpanProcessor.shutdown(timeout)
    end
  end

  @doc """
  **Application** (OTel API MUST) — ForceFlush
  (`trace/sdk.md` §ForceFlush).

  Forwards to `Otel.Trace.SpanProcessor.force_flush/1`.
  Returns `{:error, :already_shutdown}` after `shutdown/1`.
  """
  @spec force_flush(timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(timeout \\ @default_force_flush_timeout_ms) do
    case :persistent_term.get(@persistent_key, nil) do
      nil -> :ok
      %{shut_down: true} -> {:error, :already_shutdown}
      _ -> Otel.Trace.SpanProcessor.force_flush(timeout)
    end
  end

  @doc """
  **Application** (introspection) — Returns the resource
  associated with this provider, or `Otel.Resource.default/0`
  when the SDK isn't booted.
  """
  @spec resource() :: Otel.Resource.t()
  def resource, do: state().resource

  @doc """
  **Application** (introspection) — Returns the persistent_term
  state, or an empty map when the SDK isn't booted.
  """
  @spec config() :: state() | %{}
  def config, do: :persistent_term.get(@persistent_key, %{})

  @doc """
  **SDK** — Returns `true` when shutdown has been invoked.
  Used by `Otel.Trace.Tracer.enabled?/2`.
  """
  @spec shut_down?() :: boolean()
  def shut_down? do
    state = :persistent_term.get(@persistent_key, nil)
    state == nil or state.shut_down
  end

  # --- Private ---

  @spec state() :: state()
  defp state, do: :persistent_term.get(@persistent_key, default_state())

  @spec default_state() :: state()
  defp default_state do
    %{
      resource: Otel.Resource.default(),
      span_limits: %Otel.Trace.SpanLimits{},
      shut_down: false
    }
  end

  # Spec `trace/api.md` L107-L119 — *"In the case where an
  # invalid `name` (null or empty string) is specified, a
  # working `Tracer` MUST be returned as a fallback rather than
  # returning null or throwing an exception, its `name` SHOULD
  # keep the original invalid value, and a message reporting
  # that the specified value is invalid SHOULD be logged."*
  @spec warn_invalid_scope_name(scope :: Otel.InstrumentationScope.t()) :: :ok
  defp warn_invalid_scope_name(%Otel.InstrumentationScope{name: ""}) do
    Logger.warning(
      "Otel.Trace.TracerProvider: invalid Tracer name (empty string) — returning a working Tracer as fallback"
    )

    :ok
  end

  defp warn_invalid_scope_name(_scope), do: :ok
end
