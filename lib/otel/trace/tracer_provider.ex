defmodule Otel.Trace.TracerProvider do
  @moduledoc """
  TracerProvider — minikube hardcoded.

  Issues `%Otel.Trace.Tracer{}` structs. Holds no process or
  persistent state; the SDK's only user-tunable knob is the
  `:resource` `Application` env, which `Otel.Resource.from_app_env/0`
  reads on every call. Every other knob (`span_limits`, scope, etc.)
  is a compile-time literal carried by `Tracer`'s `defstruct`
  defaults.

  ## Lifecycle

  Application shutdown is delegated to OTP. `Application.stop(:otel)`
  drives the supervisor down, which calls
  `Otel.Trace.SpanProcessor.terminate/2` to drain pending spans
  and shut the exporter. There is no `shutdown/1` API on this
  module.

  ## Public API

  | Function | Role |
  |---|---|
  | `get_tracer/0` | **Application** — Get a Tracer (`trace/api.md` L107-L157) |
  | `resource/0`, `config/0` | **Application** (introspection) |

  ## References

  - OTel Trace SDK §Tracer Provider: `opentelemetry-specification/specification/trace/sdk.md` §TracerProvider
  - OTel Trace API §Tracer Provider: `opentelemetry-specification/specification/trace/api.md` §TracerProvider
  """

  @doc """
  **Application** — Get a Tracer
  (`trace/api.md` §Get a Tracer L107-L157).

  Returns a configured `%Otel.Trace.Tracer{}` struct stamped
  with the SDK's hardcoded instrumentation scope (see
  `Otel.InstrumentationScope`) and the spec-default
  `Otel.Trace.SpanLimits` (both come from `Tracer`'s `defstruct`
  defaults).
  """
  @spec get_tracer() :: Otel.Trace.Tracer.t()
  def get_tracer, do: %Otel.Trace.Tracer{}

  @doc """
  **Application** (introspection) — Returns the resource
  resolved from the `:otel` `:resource` `Application` env, or
  `Otel.Resource.default/0` when no env is set.
  """
  @spec resource() :: Otel.Resource.t()
  def resource, do: Otel.Resource.from_app_env()

  @doc """
  **Application** (introspection) — Returns a synthetic
  config map with the resolved resource. Kept for symmetry
  with the boot-time snapshot the Provider used to expose.
  """
  @spec config() :: %{resource: Otel.Resource.t()}
  def config, do: %{resource: resource()}
end
