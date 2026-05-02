defmodule Otel.SDK.Metrics.Exemplar.Filter do
  @moduledoc """
  Exemplar filters determine whether a measurement should be
  considered for exemplar sampling.

  Three built-in filters:
  - `:always_on` — sample all measurements
  - `:always_off` — never sample
  - `:trace_based` — sample only when the span is recording (default)
  """

  @type t :: :always_on | :always_off | :trace_based

  @spec should_sample?(filter :: t(), ctx :: Otel.Ctx.t()) :: boolean()
  def should_sample?(:always_on, _ctx), do: true
  def should_sample?(:always_off, _ctx), do: false

  def should_sample?(:trace_based, ctx) do
    %Otel.Trace.SpanContext{trace_flags: flags} = Otel.Trace.current_span(ctx)
    Bitwise.band(flags, 1) == 1
  end
end
