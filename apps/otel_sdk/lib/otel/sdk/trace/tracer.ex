defmodule Otel.SDK.Trace.Tracer do
  @moduledoc """
  SDK tracer implementation.

  Delegates span creation to the SDK pipeline (sampling, ID generation,
  processor notification). Full implementation in SDK Span Creation Flow
  decision.
  """

  @behaviour Otel.API.Trace.Tracer

  alias Otel.API.Trace.SpanContext

  @impl true
  def start_span(_ctx, _tracer, _name, _opts) do
    # Stub — full implementation in SDK Span Creation Flow decision
    %SpanContext{}
  end

  @impl true
  def enabled?(_tracer, _opts \\ []), do: true
end
