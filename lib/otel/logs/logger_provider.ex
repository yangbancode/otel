defmodule Otel.Logs.LoggerProvider do
  @moduledoc """
  LoggerProvider — minikube hardcoded.

  Issues `%Otel.Logs.Logger{}` structs. The `resource` flows
  from the user's `config :otel, resource: %{...}` and is
  loaded once at boot via `init/0` into `:persistent_term`;
  every other knob (`log_record_limits` etc.) is hardcoded to
  the spec defaults at compile time and stamped on the Logger
  struct's `config` map at `get_logger/0` call time.

  Not a GenServer — this module holds no process state.

  ## Lifecycle

  Application shutdown is delegated to OTP. `Application.stop(:otel)`
  drives the supervisor down, which calls
  `Otel.Logs.LogRecordProcessor.terminate/3` to drain pending
  log records and shut the exporter. There is no `shutdown/1`
  API on this module.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/0` | **SDK** (boot hook) — seed `:persistent_term` with the resolved resource |
  | `get_logger/0` | **Application** — Get a Logger (`logs/api.md` L62-L97) |
  | `resource/0`, `config/0` | **Application** (introspection) |

  ## References

  - OTel Logs SDK §LoggerProvider: `opentelemetry-specification/specification/logs/sdk.md` §LoggerProvider
  """

  @persistent_key {__MODULE__, :state}

  @typedoc "Internal provider state held in `:persistent_term`."
  @type state :: %{resource: Otel.Resource.t()}

  @doc """
  **SDK** (boot hook) — Called once from
  `Otel.Application.start/2` to seed the `:persistent_term`
  slot.
  """
  @spec init() :: :ok
  def init do
    :persistent_term.put(@persistent_key, %{resource: Otel.Resource.from_app_env()})
    :ok
  end

  @doc """
  **Application** — Get a Logger
  (`logs/api.md` §Get a Logger).

  Returns a configured `%Otel.Logs.Logger{}` struct stamped
  with the boot-time resource, the SDK's hardcoded
  instrumentation scope (see `Otel.InstrumentationScope`),
  and the spec-default log record limits.
  """
  @spec get_logger() :: Otel.Logs.Logger.t()
  def get_logger do
    %Otel.Logs.Logger{
      config: %{
        scope: %Otel.InstrumentationScope{},
        resource: state().resource,
        log_record_limits: %Otel.Logs.LogRecordLimits{}
      }
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
  defp default_state, do: %{resource: Otel.Resource.default()}
end
