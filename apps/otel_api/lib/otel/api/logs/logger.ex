defmodule Otel.API.Logs.Logger do
  @moduledoc """
  Logger behaviour and dispatch.

  A Logger is responsible for emitting LogRecords. It is represented
  as a `{module, config}` tuple where the module implements this
  behaviour. Logger SHOULD NOT be responsible for configuration —
  that is the LoggerProvider's responsibility.

  All functions are safe for concurrent use.
  """

  use Otel.API.Common.Types

  @type t :: {module(), term()}

  @type log_record :: %{
          optional(:timestamp) => integer() | nil,
          optional(:observed_timestamp) => integer() | nil,
          optional(:severity_number) => 0..24 | nil,
          optional(:severity_text) => String.t() | nil,
          optional(:body) => primitive_any(),
          optional(:attributes) => %{String.t() => primitive() | [primitive()]},
          optional(:event_name) => String.t() | nil,
          optional(:exception) => Exception.t() | nil
        }

  @typedoc """
  Options accepted by `enabled?/2`.

  Spec-defined keys:
  - `:severity_number` — severity the caller would emit (0..24)
  - `:event_name` — event name the caller would emit
  - `:ctx` — evaluation context (defaults to `Ctx.get_current/0` when omitted)
  """
  @type enabled_opt ::
          {:severity_number, 0..24}
          | {:event_name, String.t()}
          | {:ctx, Otel.API.Ctx.t()}

  @type enabled_opts :: [enabled_opt()]

  @callback emit(
              logger :: t(),
              ctx :: Otel.API.Ctx.t(),
              log_record :: log_record()
            ) :: :ok

  @callback enabled?(
              logger :: t(),
              opts :: enabled_opts()
            ) :: boolean()

  # --- Dispatch Functions ---

  @doc """
  Emits a LogRecord.

  If no context is provided, the current context is used.
  All LogRecord fields are optional.
  """
  @spec emit(logger :: t(), log_record :: log_record()) :: :ok
  def emit({module, _} = logger, log_record \\ %{}) do
    ctx = Otel.API.Ctx.current()
    module.emit(logger, ctx, log_record)
  end

  @doc """
  Emits a LogRecord with an explicit context.
  """
  @spec emit(logger :: t(), ctx :: Otel.API.Ctx.t(), log_record :: log_record()) :: :ok
  def emit({module, _} = logger, ctx, log_record) do
    module.emit(logger, ctx, log_record)
  end

  @doc """
  Returns whether the logger is enabled.

  Accepts optional `severity_number`, `event_name`, and `ctx` in opts.
  If no context is provided, the current context is used.
  """
  @spec enabled?(logger :: t(), opts :: enabled_opts()) :: boolean()
  def enabled?({module, _} = logger, opts \\ []) do
    opts =
      case Keyword.has_key?(opts, :ctx) do
        true -> opts
        false -> Keyword.put(opts, :ctx, Otel.API.Ctx.current())
      end

    module.enabled?(logger, opts)
  end
end
