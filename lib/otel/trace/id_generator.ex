defmodule Otel.Trace.IdGenerator do
  @moduledoc """
  Hardcoded random ID generator — the only generator this
  SDK ships.

  Generates non-zero random integers using `:rand.uniform/1`:
  - trace_id: 128-bit (1 to 2^128 - 1)
  - span_id: 64-bit (1 to 2^64 - 1)

  Spec ref: `trace/sdk.md` §IdGenerator. The behaviour
  abstraction (and a separate `Default` impl module) was
  collapsed because the SDK ships only this generator and
  users cannot substitute their own (per minikube-style
  scope).

  ## Public API

  | Function | Role |
  |---|---|
  | `generate_trace_id/0` | **SDK** (OTel API MUST) — `trace/sdk.md` §IdGenerator |
  | `generate_span_id/0` | **SDK** (OTel API MUST) — `trace/sdk.md` §IdGenerator |

  ## Deferred Development-status features

  - **Random TraceFlag bit.** Spec `trace/api.md` L237-L242
    defines bit 1 (`0x02`) of the W3C `trace-flags` byte as
    the *Random* flag, set when the IdGenerator produces
    trace IDs whose lower 7 bytes are random. Spec
    `trace/sdk.md` L902-L912 *"IdGenerator randomness"*
    (Status: Development) describes the SDK's responsibility
    to declare this property. Not implemented — `span.ex`
    currently sets only the Sampled bit (`0x01`) on the
    in-memory `trace_flags`. When stabilised, this module
    will gain a method describing its randomness profile and
    `span.ex` will set bit 1 accordingly.

  ## References

  - OTel Trace SDK §IdGenerator: `opentelemetry-specification/specification/trace/sdk.md`
  """

  # `bsl(1, n) - 1` reads as "n bits all set" — clearer than
  # the equivalent `bsl(2, n - 1) - 1`.
  @trace_id_max Bitwise.bsl(1, 128) - 1
  @span_id_max Bitwise.bsl(1, 64) - 1

  @doc """
  **SDK** (OTel API MUST) — Generates a 128-bit trace ID.
  """
  @spec generate_trace_id() :: Otel.Trace.TraceId.t()
  def generate_trace_id do
    Otel.Trace.TraceId.new(:rand.uniform(@trace_id_max))
  end

  @doc """
  **SDK** (OTel API MUST) — Generates a 64-bit span ID.
  """
  @spec generate_span_id() :: Otel.Trace.SpanId.t()
  def generate_span_id do
    Otel.Trace.SpanId.new(:rand.uniform(@span_id_max))
  end
end
