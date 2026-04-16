defmodule Otel.API.Logs.Logger do
  @moduledoc """
  Logger behaviour and dispatch.

  A Logger is responsible for emitting LogRecords. It is represented
  as a `{module, config}` tuple where the module implements this
  behaviour. Logger SHOULD NOT be responsible for configuration —
  that is the LoggerProvider's responsibility.

  All functions are safe for concurrent use.
  """

  @type t :: {module(), term()}

  @type log_record :: %{
          optional(:timestamp) => integer() | nil,
          optional(:observed_timestamp) => integer() | nil,
          optional(:severity_number) => 1..24 | nil,
          optional(:severity_text) => String.t() | nil,
          optional(:body) => term() | nil,
          optional(:attributes) => map(),
          optional(:event_name) => String.t() | nil,
          optional(:exception) => Exception.t() | nil
        }

  @callback emit(
              logger :: t(),
              ctx :: Otel.API.Ctx.t(),
              log_record :: log_record()
            ) :: :ok

  @callback enabled?(
              logger :: t(),
              opts :: keyword()
            ) :: boolean()

  # --- Dispatch Functions ---

  @doc """
  Emits a LogRecord.

  If no context is provided, the current context is used.
  All LogRecord fields are optional.
  """
  @spec emit(logger :: t(), log_record :: log_record()) :: :ok
  def emit({module, _} = logger, log_record \\ %{}) do
    ctx = Otel.API.Ctx.get_current()
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
  @spec enabled?(logger :: t(), opts :: keyword()) :: boolean()
  def enabled?({module, _} = logger, opts \\ []) do
    opts =
      case Keyword.has_key?(opts, :ctx) do
        true -> opts
        false -> Keyword.put(opts, :ctx, Otel.API.Ctx.get_current())
      end

    module.enabled?(logger, opts)
  end
end
