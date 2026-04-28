defmodule Otel.SDK.Trace.IdGenerator do
  @moduledoc """
  Behaviour for trace ID and span ID generation.

  The SDK randomly generates IDs by default. Custom implementations
  can be provided via TracerProvider configuration.

  ## Deferred Development-status features

  - **Random TraceFlag bit.** Spec `trace/api.md` L237-L242
    defines bit 1 (`0x02`) of the W3C `trace-flags` byte as
    the *Random* flag, set when the IdGenerator produces
    trace IDs whose lower 7 bytes are random. Spec
    `trace/sdk.md` L902-L912 *"IdGenerator randomness"*
    (Status: Development) describes the SDK's responsibility
    to declare this property. Not implemented — `span.ex`
    currently sets only the Sampled bit (`0x01`) on the
    in-memory `trace_flags`. When stabilised, the IdGenerator
    behaviour will gain a method describing its randomness
    profile and `span.ex` will set bit 1 accordingly.
  """

  @doc """
  Generates a 128-bit trace ID.
  """
  @callback generate_trace_id() :: Otel.API.Trace.TraceId.t()

  @doc """
  Generates a 64-bit span ID.
  """
  @callback generate_span_id() :: Otel.API.Trace.SpanId.t()
end
