defmodule Otel.API.Logs.Logger.Noop do
  @moduledoc """
  No-op Logger implementation.

  Used when no SDK is installed. All emit calls are ignored,
  and `enabled?` returns `false`.

  All functions are safe for concurrent use.
  """

  @behaviour Otel.API.Logs.Logger

  @impl true
  @spec emit(
          logger :: Otel.API.Logs.Logger.t(),
          ctx :: Otel.API.Ctx.t(),
          log_record :: Otel.API.Logs.Logger.log_record()
        ) :: :ok
  def emit(_logger, _ctx, _log_record), do: :ok

  @impl true
  @spec enabled?(logger :: Otel.API.Logs.Logger.t(), opts :: keyword()) :: boolean()
  def enabled?(_logger, _opts), do: false
end
