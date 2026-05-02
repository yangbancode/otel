defmodule Otel.SDK.Trace.Tracer do
  @moduledoc """
  SDK implementation of the `Otel.API.Trace.Tracer` behaviour
  (`trace/sdk.md` §Tracer L120-L228).

  All configuration (span_limits, processors, scope) is stored in
  the tracer tuple at creation time. No GenServer calls during
  span creation for performance. Sampling is hardcoded to
  `Otel.SDK.Trace.Sampler` (parentbased_always_on); ID generation
  to `Otel.SDK.Trace.IdGenerator` (random).

  All functions are safe for concurrent use, satisfying spec
  `trace/api.md` L843-L853 (Status: Stable, #4887) — *"Tracer —
  all methods MUST be documented that implementations need to
  be safe for concurrent use by default."*

  ## Public API

  | Function | Role |
  |---|---|
  | `start_span/4` | **SDK** (OTel API MUST) — `trace/api.md` §Span Creation L378-L414 |
  | `with_span/5` | **SDK** (OTel API MAY) — `trace/api.md` L385 closure form |
  | `enabled?/2` | **SDK** (OTel API MUST) — `trace/sdk.md` L223-L227 |

  ## References

  - OTel Trace SDK §Tracer: `opentelemetry-specification/specification/trace/sdk.md` L120-L228
  - OTel Trace API §Tracer: `opentelemetry-specification/specification/trace/api.md` L160-L416
  """

  @behaviour Otel.API.Trace.Tracer

  @doc """
  **SDK** (OTel API MUST) — Span Creation
  (`trace/api.md` §Span Creation L378-L414).

  Delegates to `Otel.SDK.Trace.Span.start_span/4` for sampling
  and ID generation, then stamps tracer-resolved fields (scope,
  limits, processors), runs `on_start/3` on every registered
  processor, and inserts the span into ETS storage.
  """
  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(ctx, {__MODULE__, config}, name, opts) do
    {span_ctx, span} =
      Otel.SDK.Trace.Span.start_span(ctx, name, config.span_limits, opts)

    if span do
      processors = :persistent_term.get(config.processors_key, [])

      span
      |> Map.merge(%{
        instrumentation_scope: config.scope,
        span_limits: config.span_limits,
        processors_key: config.processors_key
      })
      |> run_on_start(ctx, processors)
      |> Otel.SDK.Trace.SpanStorage.insert()
    end

    span_ctx
  end

  @doc """
  **SDK** (OTel API MAY) — `start_span` + `make_current` +
  closure + `end_span` in one call (`trace/api.md` L385).

  Records exception attributes and sets `:error` status on
  any raised exception / thrown value / exit, then re-raises
  to preserve caller-side error handling. The `try/catch`
  here is the spec-mandated exception-recording contract,
  not error handling per `code-conventions.md`.
  """
  @spec with_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: Otel.API.Trace.Span.start_opts(),
          fun :: (Otel.API.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  @impl true
  def with_span(ctx, tracer, name, opts, fun) do
    span_ctx = start_span(ctx, tracer, name, opts)
    new_ctx = Otel.API.Trace.set_current_span(ctx, span_ctx)
    token = Otel.API.Ctx.attach(new_ctx)

    try do
      fun.(span_ctx)
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__

        case kind do
          :error ->
            normalized = Exception.normalize(:error, reason, stacktrace)
            Otel.API.Trace.Span.record_exception(span_ctx, normalized, stacktrace)

            Otel.API.Trace.Span.set_status(
              span_ctx,
              Otel.API.Trace.Status.new(:error, Exception.message(normalized))
            )

          _ ->
            Otel.API.Trace.Span.set_status(
              span_ctx,
              Otel.API.Trace.Status.new(:error, Exception.format(kind, reason))
            )
        end

        :erlang.raise(kind, reason, stacktrace)
    after
      Otel.API.Trace.Span.end_span(span_ctx)
      Otel.API.Ctx.detach(token)
    end
  end

  @doc """
  **SDK** (OTel API MUST) — `Enabled`
  (`trace/sdk.md` L223-L227, Status: Development).

  Spec MUST: returns false when either there are no registered
  SpanProcessors, or `TracerConfig.enabled` is false.
  TracerConfig itself is Development-status and not yet
  implemented (see `Otel.SDK.Trace.TracerProvider` `## Deferred
  Development-status features`); only the no-processors leg is
  honoured today.
  """
  @spec enabled?(
          tracer :: Otel.API.Trace.Tracer.t(),
          opts :: Otel.API.Trace.Tracer.enabled_opts()
        ) :: boolean()
  @impl true
  def enabled?({__MODULE__, config}, _opts \\ []) do
    :persistent_term.get(config.processors_key, []) != []
  end

  @spec run_on_start(
          span :: Otel.SDK.Trace.Span.t(),
          ctx :: Otel.API.Ctx.t(),
          processors :: [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
        ) :: Otel.SDK.Trace.Span.t()
  defp run_on_start(span, ctx, processors) do
    Enum.reduce(processors, span, fn {processor, processor_config}, acc ->
      processor.on_start(ctx, acc, processor_config)
    end)
  end
end
