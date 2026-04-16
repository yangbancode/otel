defmodule Otel.API.Logs.Logger.Noop do
  @moduledoc """
  No-op Logger implementation.

  Used when no SDK is installed. All emit calls are ignored,
  and `enabled?` returns `false`.

  All functions are safe for concurrent use.
  """

  @behaviour Otel.API.Logs.Logger

  @impl true
  def emit(_logger, _ctx, _log_record), do: :ok

  @impl true
  def enabled?(_logger, _opts), do: false
end
