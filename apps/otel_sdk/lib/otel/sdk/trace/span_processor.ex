defmodule Otel.SDK.Trace.SpanProcessor do
  @moduledoc """
  Behaviour for span processors
  (`trace/sdk.md` §SpanProcessor L946-L1075).

  Span processors receive span lifecycle events (on_start, on_end)
  and are responsible for batching and passing spans to exporters.
  Called synchronously — implementations MUST NOT block or throw.

  ## Public API

  | Callback | Role |
  |---|---|
  | `on_start/3` | **SDK** (OTel API MUST) — `trace/sdk.md` L963-L982 |
  | `on_end/2` | **SDK** (OTel API MUST) — `trace/sdk.md` L1005-L1027 |
  | `shutdown/2` | **SDK** (OTel API MUST) — `trace/sdk.md` §Shutdown |
  | `force_flush/2` | **SDK** (OTel API MUST) — `trace/sdk.md` §ForceFlush |

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

  ## References

  - OTel Trace SDK §SpanProcessor: `opentelemetry-specification/specification/trace/sdk.md` L946-L1075
  - Built-in implementations: `Otel.SDK.Trace.SpanProcessor.Simple`, `Otel.SDK.Trace.SpanProcessor.Batch`
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
  Shuts down the processor. Must include the effects of
  force_flush. `timeout` is the upper bound the processor
  SHOULD honour for the whole shutdown sequence per
  `trace/sdk.md` §Shutdown.
  """
  @callback shutdown(config :: config(), timeout :: timeout()) :: :ok | {:error, term()}

  @doc """
  Forces the processor to export all pending spans immediately.
  `timeout` bounds the wait per `trace/sdk.md` §ForceFlush.
  """
  @callback force_flush(config :: config(), timeout :: timeout()) :: :ok | {:error, term()}
end
