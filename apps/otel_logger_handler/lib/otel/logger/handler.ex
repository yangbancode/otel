defmodule Otel.Logger.Handler do
  @moduledoc """
  Logger handler for OpenTelemetry.

  Bridges Erlang's `:logger` to the OpenTelemetry Logs API, converting
  log messages into OTel Log Records without code changes.
  """
end
