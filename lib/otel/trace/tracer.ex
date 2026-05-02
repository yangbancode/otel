defmodule Otel.Trace.Tracer do
  @moduledoc """
  Creates `Span`s. Returned by `Otel.Trace.TracerProvider.get_tracer/1`.

  All configuration (span_limits, processors, scope) is stored
  in the tracer struct at creation time so span creation needs
  no GenServer call. Sampling is hardcoded to
  `Otel.Trace.Sampler` (parentbased_always_on); ID generation
  to `Otel.Trace.IdGenerator` (random).

  All functions are safe for concurrent use, satisfying spec
  `trace/api.md` L843-L853 (Status: Stable, #4887) — *"Tracer —
  all methods MUST be documented that implementations need to
  be safe for concurrent use by default."*

  ## Public API

  | Function | Role |
  |---|---|
  | `start_span/4` | OTel API MUST — `trace/api.md` §Span Creation L378-L414 |
  | `with_span/5` | OTel API MAY — `trace/api.md` L385 closure form |
  | `enabled?/2` | OTel API MUST — `trace/sdk.md` L223-L227 |

  ## References

  - OTel Trace SDK §Tracer: `opentelemetry-specification/specification/trace/sdk.md` L120-L228
  - OTel Trace API §Tracer: `opentelemetry-specification/specification/trace/api.md` L160-L416
  """

  @typedoc """
  A Tracer struct.

  - `scope` — instrumentation scope this tracer was issued for.
  - `span_limits` — span limits resolved at provider boot.
  - `processors_key` — `:persistent_term` key for the processor
    list; written by the TracerProvider at boot.
  """
  @type t :: %__MODULE__{
          scope: Otel.InstrumentationScope.t(),
          span_limits: Otel.Trace.SpanLimits.t(),
          processors_key: atom()
        }

  defstruct scope: %Otel.InstrumentationScope{},
            span_limits: %Otel.Trace.SpanLimits{},
            processors_key: nil

  @typedoc "Options accepted by `enabled?/2`. Per spec L208-L210 currently no required parameters."
  @type enabled_opts :: keyword()

  @doc """
  OTel API MUST — Span Creation (`trace/api.md` §Span Creation
  L378-L414).

  Delegates to `Otel.Trace.Span.start_span/4` for sampling and
  ID generation, then stamps tracer-resolved fields (scope,
  limits, processors), runs `on_start/3` on every registered
  processor, and inserts the span into ETS storage.
  """
  @spec start_span(
          ctx :: Otel.Ctx.t(),
          tracer :: t(),
          name :: String.t(),
          opts :: Otel.Trace.Span.start_opts()
        ) :: Otel.Trace.SpanContext.t()
  def start_span(ctx, %__MODULE__{} = tracer, name, opts) do
    {span_ctx, span} =
      Otel.Trace.Span.start_span(ctx, name, tracer.span_limits, opts)

    if span do
      processors = :persistent_term.get(tracer.processors_key, [])

      span
      |> Map.merge(%{
        instrumentation_scope: tracer.scope,
        span_limits: tracer.span_limits,
        processors_key: tracer.processors_key
      })
      |> run_on_start(ctx, processors)
      |> Otel.Trace.SpanStorage.insert()
    end

    span_ctx
  end

  @doc """
  OTel API MAY — `start_span` + `make_current` + closure +
  `end_span` in one call (`trace/api.md` L385).

  Records exception attributes and sets `:error` status on any
  raised exception / thrown value / exit, then re-raises to
  preserve caller-side error handling. The `try/catch` here is
  the spec-mandated exception-recording contract, not error
  handling per `code-conventions.md`.
  """
  @spec with_span(
          ctx :: Otel.Ctx.t(),
          tracer :: t(),
          name :: String.t(),
          opts :: Otel.Trace.Span.start_opts(),
          fun :: (Otel.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  def with_span(ctx, %__MODULE__{} = tracer, name, opts, fun) do
    span_ctx = start_span(ctx, tracer, name, opts)
    new_ctx = Otel.Trace.set_current_span(ctx, span_ctx)
    token = Otel.Ctx.attach(new_ctx)

    try do
      fun.(span_ctx)
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__

        case kind do
          :error ->
            normalized = Exception.normalize(:error, reason, stacktrace)
            Otel.Trace.Span.record_exception(span_ctx, normalized, stacktrace)

            Otel.Trace.Span.set_status(
              span_ctx,
              Otel.Trace.Status.new(:error, Exception.message(normalized))
            )

          _ ->
            Otel.Trace.Span.set_status(
              span_ctx,
              Otel.Trace.Status.new(:error, Exception.format(kind, reason))
            )
        end

        :erlang.raise(kind, reason, stacktrace)
    after
      Otel.Trace.Span.end_span(span_ctx)
      Otel.Ctx.detach(token)
    end
  end

  @doc """
  OTel API MUST — `Enabled` (`trace/sdk.md` L223-L227,
  Status: Development).

  Returns `false` when there are no registered SpanProcessors.
  TracerConfig (`enabled` flag) is spec-Development and not
  implemented; only the no-processors leg is honoured.
  """
  @spec enabled?(tracer :: t(), opts :: enabled_opts()) :: boolean()
  def enabled?(%__MODULE__{} = tracer, _opts \\ []) do
    :persistent_term.get(tracer.processors_key, []) != []
  end

  @spec run_on_start(
          span :: Otel.Trace.Span.t(),
          ctx :: Otel.Ctx.t(),
          processors :: [{module(), Otel.Trace.SpanProcessor.config()}]
        ) :: Otel.Trace.Span.t()
  defp run_on_start(span, ctx, processors) do
    Enum.reduce(processors, span, fn {processor, processor_config}, acc ->
      processor.on_start(ctx, acc, processor_config)
    end)
  end
end
