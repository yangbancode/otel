defmodule Otel.Logs.LoggerProvider do
  @moduledoc """
  LoggerProvider — minikube hardcoded.

  Issues `%Otel.Logs.Logger{}` structs and forwards
  `shutdown/1` / `force_flush/1` to the single hardcoded
  `Otel.Logs.LogRecordProcessor` (Batch). Configuration
  (`resource`, `log_record_limits`) is loaded once at boot via
  `init/0` and stored in `:persistent_term`; subsequent
  `get_logger/1` calls are pure persistent_term reads.

  Not a GenServer — this module holds no process state.

  ## Public API

  | Function | Role |
  |---|---|
  | `init/0` | **SDK** (boot hook) — seed `:persistent_term` (resource + spec-default log_record_limits) |
  | `get_logger/1` | **Application** (OTel API MUST) — Get a Logger (`logs/api.md` L62-L97) |
  | `shutdown/1` | **Application** (OTel API MUST) — Shutdown (`logs/sdk.md` §Shutdown) |
  | `force_flush/1` | **Application** (OTel API MUST) — ForceFlush (`logs/sdk.md` §ForceFlush) |
  | `resource/0`, `config/0` | **Application** (introspection) |
  | `shut_down?/0` | **SDK** — internal flag for `Logger.enabled?/2` |

  ## References

  - OTel Logs SDK §LoggerProvider: `opentelemetry-specification/specification/logs/sdk.md` §LoggerProvider
  """

  @persistent_key {__MODULE__, :state}

  @default_shutdown_timeout_ms 30_000
  @default_force_flush_timeout_ms 30_000

  @typedoc "Internal provider state held in `:persistent_term`."
  @type state :: %{
          resource: Otel.Resource.t(),
          log_record_limits: Otel.Logs.LogRecordLimits.t(),
          shut_down: boolean()
        }

  @doc """
  **SDK** (boot hook) — Called once from
  `Otel.Application.start/2` to seed the `:persistent_term`
  slot. `log_record_limits` is hardcoded to the spec defaults;
  only the resource flows from the user's
  `config :otel, resource: %{...}`.
  """
  @spec init() :: :ok
  def init do
    :persistent_term.put(@persistent_key, %{
      resource: Otel.Resource.from_app_env(),
      log_record_limits: %Otel.Logs.LogRecordLimits{},
      shut_down: false
    })

    :ok
  end

  @doc """
  **Application** (OTel API MUST) — Get a Logger
  (`logs/api.md` §Get a Logger).

  Returns a configured `%Otel.Logs.Logger{}` struct stamped
  with the boot-time resource/limits and the SDK's hardcoded
  instrumentation scope (see `Otel.InstrumentationScope`).
  After `shutdown/1`, returns an empty Logger.
  """
  @spec get_logger() :: Otel.Logs.Logger.t()
  def get_logger do
    state = state()

    if state.shut_down do
      %Otel.Logs.Logger{}
    else
      logger_config = %{
        scope: %Otel.InstrumentationScope{},
        resource: state.resource,
        log_record_limits: state.log_record_limits
      }

      %Otel.Logs.Logger{config: logger_config}
    end
  end

  @doc """
  **Application** (OTel API MUST) — Shutdown
  (`logs/sdk.md` §Shutdown).
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
        Otel.Logs.LogRecordProcessor.shutdown(timeout)
    end
  end

  @doc """
  **Application** (OTel API MUST) — ForceFlush
  (`logs/sdk.md` §ForceFlush).
  """
  @spec force_flush(timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(timeout \\ @default_force_flush_timeout_ms) do
    case :persistent_term.get(@persistent_key, nil) do
      nil -> :ok
      %{shut_down: true} -> {:error, :already_shutdown}
      _ -> Otel.Logs.LogRecordProcessor.force_flush(timeout)
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
      log_record_limits: %Otel.Logs.LogRecordLimits{},
      shut_down: false
    }
  end
end
