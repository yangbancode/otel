defmodule Otel.API.Trace.Tracer.Noop do
  @moduledoc """
  No-op Tracer used when no SDK is installed (spec `trace/api.md`
  §Behavior of the API in the absence of an installed SDK,
  L860-L874, Status: **Stable**).

  Spec summary (L862-L874):

  - Operations MUST have no side effects and do nothing (L862-L863).
  - `start_span` MUST return a non-recording Span whose
    `SpanContext` comes from the parent Context when present
    (L865-L866).
  - If the parent Span is already non-recording, it SHOULD be
    returned directly without instantiating a new Span (L867-L868).
    Elixir's value semantics make this equivalent to returning a
    fresh default struct — the caller cannot observe a difference.
  - If the parent Context contains no Span, an empty non-recording
    Span MUST be returned: all-zero `trace_id`/`span_id`, empty
    `TraceState`, unsampled `TraceFlags` (L869-L871). This is the
    `%Otel.API.Trace.SpanContext{}` default struct.

  `enabled?/2` returns `false` per spec L201-L213 (Enabled is a
  SHOULD API; a no-op tracer is never enabled).

  Registered as the default tracer by `Otel.API.Trace.TracerProvider`
  and by the SDK tracer provider when no tracer is configured.

  ## Public API

  | Function | Role |
  |---|---|
  | `start_span/4` | **OTel API MUST** (no-op behaviour) |
  | `with_span/5` | **OTel convenience** (no-op lifecycle) |
  | `enabled?/2` | **OTel API SHOULD** (always `false`) |

  ## References

  - OTel Trace API §Behavior in absence of SDK: `opentelemetry-specification/specification/trace/api.md` L860-L874
  - OTel Trace API §Enabled: `opentelemetry-specification/specification/trace/api.md` L201-L213
  """

  @behaviour Otel.API.Trace.Tracer

  @impl true
  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: Otel.API.Trace.SpanContext.t()
  def start_span(ctx, _tracer, _name, _opts) do
    case Otel.API.Trace.current_span(ctx) do
      %Otel.API.Trace.SpanContext{trace_id: trace_id} = parent when trace_id != 0 ->
        parent

      _ ->
        # Spec L869-L871: empty non-recording Span when no parent.
        %Otel.API.Trace.SpanContext{}
    end
  end

  @impl true
  @spec with_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: Otel.API.Trace.Span.start_opts(),
          fun :: (Otel.API.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  def with_span(ctx, tracer, name, opts, fun) do
    span_ctx = start_span(ctx, tracer, name, opts)
    new_ctx = Otel.API.Trace.set_current_span(ctx, span_ctx)
    token = Otel.API.Ctx.attach(new_ctx)

    try do
      fun.(span_ctx)
    after
      Otel.API.Ctx.detach(token)
    end
  end

  @impl true
  @spec enabled?(
          tracer :: Otel.API.Trace.Tracer.t(),
          opts :: Otel.API.Trace.Tracer.enabled_opts()
        ) :: boolean()
  def enabled?(_tracer, _opts \\ []), do: false
end
