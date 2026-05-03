defmodule Otel.Logs.LoggerProvider do
  @moduledoc """
  LoggerProvider — minikube hardcoded.

  Issues `%Otel.Logs.Logger{}` structs. Holds no process or
  persistent state; the SDK's only user-tunable knob is the
  `:resource` `Application` env, which `Otel.Resource.from_app_env/0`
  reads on every call. Every other knob (`log_record_limits`,
  scope, etc.) is a compile-time literal stamped on the
  `%Logger{}.config` map at `get_logger/0` call time.

  ## Lifecycle

  Application shutdown is delegated to OTP. `Application.stop(:otel)`
  drives the supervisor down, which calls
  `Otel.Logs.LogRecordProcessor.terminate/3` to drain pending
  log records and shut the exporter. There is no `shutdown/1`
  API on this module.

  ## Public API

  | Function | Role |
  |---|---|
  | `get_logger/0` | **Application** — Get a Logger (`logs/api.md` L62-L97) |
  | `resource/0`, `config/0` | **Application** (introspection) |

  ## References

  - OTel Logs SDK §LoggerProvider: `opentelemetry-specification/specification/logs/sdk.md` §LoggerProvider
  """

  @doc """
  **Application** — Get a Logger
  (`logs/api.md` §Get a Logger).

  Returns a configured `%Otel.Logs.Logger{}` struct stamped
  with the resolved resource, the SDK's hardcoded instrumentation
  scope (see `Otel.InstrumentationScope`), and the spec-default
  log record limits.
  """
  @spec get_logger() :: Otel.Logs.Logger.t()
  def get_logger do
    %Otel.Logs.Logger{
      config: %{
        scope: %Otel.InstrumentationScope{},
        resource: Otel.Resource.from_app_env(),
        log_record_limits: %Otel.Logs.LogRecordLimits{}
      }
    }
  end

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
