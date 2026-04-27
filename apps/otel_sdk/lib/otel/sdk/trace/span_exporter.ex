defmodule Otel.SDK.Trace.SpanExporter do
  @moduledoc """
  Behaviour for span exporters
  (`trace/sdk.md` §Span Exporter L1120-L1209).

  Exporters receive batches of completed spans and transmit them
  to a backend. Protocol-specific logic (encoding, transport) lives
  in the exporter implementation.

  `export/3` MUST NOT be called concurrently for the same
  instance — the SpanProcessor serialises calls per spec
  L1146-L1147. `shutdown/1` is invoked once at provider
  shutdown.

  Spec `trace/sdk.md` L1135 — *"The exporter MUST support three
  functions: Export, Shutdown, and ForceFlush"*. All three are
  required callbacks of this behaviour. Most exporters implement
  `force_flush/1` as a no-op because they don't internally
  buffer (the `Batch` SpanProcessor does the buffering and calls
  `export/3` synchronously); the callback exists so the
  TracerProvider's force-flush path can propagate cleanly through
  the processor → exporter chain.

  ## Public API

  | Callback | Role |
  |---|---|
  | `init/1` | **SDK** (lifecycle) |
  | `export/3` | **SDK** (OTel API MUST) — `trace/sdk.md` §Export L1139-L1164 |
  | `shutdown/1` | **SDK** (OTel API MUST) — `trace/sdk.md` §Shutdown L1182-L1206 |
  | `force_flush/1` | **SDK** (OTel API MUST) — `trace/sdk.md` §ForceFlush L1167-L1180 |

  ## References

  - OTel Trace SDK §Span Exporter: `opentelemetry-specification/specification/trace/sdk.md` L1120-L1209
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

  @doc """
  Flushes any pending spans. For exporters that don't internally
  buffer, this is a no-op returning `:ok`.
  """
  @callback force_flush(state :: state()) :: :ok | :error
end
