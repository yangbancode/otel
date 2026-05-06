defmodule Otel.Metrics.Exemplar.Filter do
  @moduledoc """
  Exemplar filter — `trace_based` only.

  Spec `metrics/sdk.md` L1377-L1379 lists `:always_on`,
  `:always_off`, and `:trace_based`; minikube hardcodes
  `:trace_based` because it's the only branch that respects
  the wire-format input (parent span's W3C `trace_flags`).
  Same shape as `Otel.Trace.Sampler`'s preserved `:drop`
  decision: a wire-format invariant remains after the
  user-policy filters are stripped.
  """

  @spec should_sample?(ctx :: Otel.Ctx.t()) :: boolean()
  def should_sample?(ctx) do
    %Otel.Trace.SpanContext{trace_flags: flags} = Otel.Trace.current_span(ctx)
    Bitwise.band(flags, 1) == 1
  end
end
