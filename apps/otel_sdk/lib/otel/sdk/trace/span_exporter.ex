defmodule Otel.SDK.Trace.SpanExporter do
  @moduledoc """
  Behaviour for span exporters.

  Exporters receive batches of completed spans and transmit them
  to a backend. Protocol-specific logic (encoding, transport) lives
  in the exporter implementation.

  Export MUST NOT be called concurrently for the same instance.
  The processor serializes export calls.
  """

  @type state :: term()

  @doc """
  Initializes the exporter. Returns `{:ok, state}` or `:ignore`.
  """
  @callback init(config :: term()) :: {:ok, state()} | :ignore

  @doc """
  Exports a batch of spans. MUST NOT block indefinitely.
  """
  @callback export(
              spans :: [Otel.SDK.Trace.Span.t()],
              resource :: Otel.SDK.Resource.t(),
              state :: state()
            ) :: :ok | :error

  @doc """
  Shuts down the exporter.
  """
  @callback shutdown(state :: state()) :: :ok
end
