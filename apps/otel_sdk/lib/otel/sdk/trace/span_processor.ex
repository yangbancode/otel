defmodule Otel.SDK.Trace.SpanProcessor do
  @moduledoc """
  Behaviour for span processors.

  Span processors receive span lifecycle events (on_start, on_end)
  and are responsible for batching and passing spans to exporters.
  Called synchronously — implementations MUST NOT block or throw.

  ## Deferred Development-status features

  - **OnEnding callback.** Spec `trace/sdk.md` L959-L961 +
    L983-L1003 (Status: Development) describes an `OnEnding`
    method called *during* `Span.End()` — after the end
    timestamp is computed but before the span becomes
    immutable. The hook lets processors apply last-moment
    mutations (`SetAttribute`, `AddEvent`, `AddLink`)
    synchronously before any `OnEnd` fires. Not implemented:
    no `@callback on_ending/2` here, and `Otel.SDK.Trace.Span`
    transitions directly from end-time computation to
    `take/1` (storage removal) without invoking processors
    mid-flight. Waits for spec stabilisation.
  """

  @type config :: term()

  @doc """
  Called when a span is started. Must not block or throw.
  Returns the (possibly modified) span.
  """
  @callback on_start(
              ctx :: Otel.API.Ctx.t(),
              span :: Otel.SDK.Trace.Span.t(),
              config :: config()
            ) :: Otel.SDK.Trace.Span.t()

  @doc """
  Called after a span is ended. Must not block or throw.
  """
  @callback on_end(span :: Otel.SDK.Trace.Span.t(), config :: config()) ::
              :ok | :dropped | {:error, term()}

  @doc """
  Shuts down the processor. Must include the effects of force_flush.
  """
  @callback shutdown(config :: config()) :: :ok | {:error, term()}

  @doc """
  Forces the processor to export all pending spans immediately.
  """
  @callback force_flush(config :: config()) :: :ok | {:error, term()}
end
