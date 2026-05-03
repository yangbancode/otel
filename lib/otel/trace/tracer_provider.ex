defmodule Otel.Trace.TracerProvider do
  @moduledoc """
  TracerProvider — minikube hardcoded.

  Issues `%Otel.Trace.Tracer{}` structs. Configuration
  (`resource`, `span_limits`) is loaded once at boot via
  `init/0` and stored in `:persistent_term`; subsequent
  `get_tracer/0` calls are pure persistent_term reads.

  Not a GenServer — this module holds no process state. The
  three siblings under `Otel.Application` that *do* hold state
  are the BatchProcessor itself, `Otel.Trace.SpanStorage` (ETS
  owner), and the configured exporter.

  ## Lifecycle

  Application shutdown is delegated to OTP. `Application.stop(:otel)`
  drives the supervisor down, which calls
  `Otel.Trace.SpanProcessor.terminate/2` to drain pending spans
  and shut the exporter. There is no `shutdown/1` API on this
  module.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/0` | **SDK** (boot hook) — seed `:persistent_term` (resource + spec-default span_limits) |
  | `get_tracer/0` | **Application** — Get a Tracer (`trace/api.md` L107-L157) |
  | `resource/0`, `config/0` | **Application** (introspection) |

  ## References

  - OTel Trace SDK §Tracer Provider: `opentelemetry-specification/specification/trace/sdk.md` §TracerProvider
  - OTel Trace API §Tracer Provider: `opentelemetry-specification/specification/trace/api.md` §TracerProvider
  """

  @persistent_key {__MODULE__, :state}

  @typedoc "Internal provider state held in `:persistent_term`."
  @type state :: %{
          resource: Otel.Resource.t(),
          span_limits: Otel.Trace.SpanLimits.t()
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
      span_limits: %Otel.Trace.SpanLimits{}
    })

    :ok
  end

  @doc """
  **Application** — Get a Tracer
  (`trace/api.md` §Get a Tracer L107-L157).

  Returns a configured `%Otel.Trace.Tracer{}` struct stamped
  with the boot-time resource/limits and the SDK's hardcoded
  instrumentation scope (see `Otel.InstrumentationScope`).
  """
  @spec get_tracer() :: Otel.Trace.Tracer.t()
  def get_tracer do
    %Otel.Trace.Tracer{
      scope: %Otel.InstrumentationScope{},
      span_limits: state().span_limits
    }
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

  # --- Private ---

  @spec state() :: state()
  defp state, do: :persistent_term.get(@persistent_key, default_state())

  @spec default_state() :: state()
  defp default_state do
    %{
      resource: Otel.Resource.default(),
      span_limits: %Otel.Trace.SpanLimits{}
    }
  end
end
