defmodule Otel.Trace.Sampler do
  @moduledoc """
  Hard-coded `ParentBased(root=AlwaysOn)` sampler — the spec
  default per `trace/sdk.md` L421 and the only sampler this
  SDK ships.

  Decision matrix (`trace/sdk.md` §ParentBased L584-590 with
  default delegates L579-582):

  | Parent              | Decision           |
  |---------------------|--------------------|
  | absent (root)       | `record_and_sample`|
  | sampled (any)       | `record_and_sample`|
  | not sampled (any)   | `drop`             |

  The full 5-branch ParentBased decorator is collapsed because
  every branch resolves to `AlwaysOn` (sampled) or `AlwaysOff`
  (not sampled) — local/remote distinction has no behavioural
  effect with default delegates.

  ## Public API

  | Function | Role |
  |---|---|
  | `should_sample/6` | **SDK** (OTel API MUST) — `trace/sdk.md` §ShouldSample L342-L406 |
  | `description/0` | **SDK** (OTel API MUST) — `trace/sdk.md` §GetDescription L408-L417 |

  All functions are safe for concurrent use, satisfying spec
  `trace/sdk.md` L1284 — *"Sampler — ShouldSample and
  GetDescription MUST be safe to be called concurrently."*

  ## References

  - OTel Trace SDK §Sampler: `opentelemetry-specification/specification/trace/sdk.md` L329-L460
  - OTel Trace SDK §Built-in samplers: same file L418-L590
  """

  use Otel.Common.Types

  @type sampling_decision :: :drop | :record_only | :record_and_sample
  @type sampling_result :: {
          sampling_decision(),
          %{String.t() => primitive_any()},
          Otel.Trace.TraceState.t()
        }

  @doc """
  **SDK** (OTel API MUST) — `GetDescription`
  (`trace/sdk.md` §GetDescription L408-L417).

  Returns the spec-style ParentBased descriptor with all five
  delegate branches enumerated. ParentBased itself has no MUST
  format; this format mirrors the description the previous
  composable implementation produced, so external observers
  (debug pages, log lines) see no string change.
  """
  @spec description() :: String.t()
  def description,
    do:
      "ParentBased{root:AlwaysOnSampler,remoteParentSampled:AlwaysOnSampler,remoteParentNotSampled:AlwaysOffSampler,localParentSampled:AlwaysOnSampler,localParentNotSampled:AlwaysOffSampler}"

  @doc """
  **SDK** (OTel API MUST) — `ShouldSample`
  (`trace/sdk.md` §ShouldSample L342-L406).

  Returns `record_and_sample` for root spans and any span
  whose parent has the sampled bit set; `drop` for spans whose
  parent has the bit unset. Tracestate is propagated from the
  parent unchanged.
  """
  @spec should_sample(
          ctx :: Otel.Ctx.t(),
          trace_id :: Otel.Trace.TraceId.t(),
          links :: [Otel.Trace.Link.t()],
          name :: String.t(),
          kind :: Otel.Trace.SpanKind.t(),
          attributes :: %{String.t() => primitive_any()}
        ) :: sampling_result()
  def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes) do
    parent = Otel.Trace.current_span(ctx)
    {decide(parent), %{}, parent.tracestate}
  end

  @spec decide(parent :: Otel.Trace.SpanContext.t()) :: sampling_decision()
  defp decide(parent) do
    cond do
      not Otel.Trace.SpanContext.valid?(parent) -> :record_and_sample
      sampled?(parent) -> :record_and_sample
      true -> :drop
    end
  end

  @spec sampled?(parent :: Otel.Trace.SpanContext.t()) :: boolean()
  defp sampled?(%Otel.Trace.SpanContext{trace_flags: flags}),
    do: Bitwise.band(flags, 1) != 0
end
