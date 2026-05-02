defmodule Otel.Trace.Link.Impl do
  @moduledoc """
  SDK-internal representation of a Span Link.

  Mirrors the proto `Span.Link` message
  (`opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto`
  L252-L290) so the encoder can emit it 1:1, including the
  `dropped_attributes_count` field that the OTel
  `common/mapping-to-non-otlp.md` L75-L77 MUST requires per
  data entity.

  This struct is constructed by the SDK from the API-layer
  `Otel.Trace.Link` at the moment limits are applied
  (`Otel.Trace.Span.Impl.add_link/2`,
  `Otel.Trace.Span.Impl.start_span/6` for links provided at
  creation time). Application code should not construct
  this struct directly — use `%Otel.Trace.Link{...}` and
  pass the result to `Otel.Trace.Span.add_link/2`.

  ## Why a separate SDK type?

  `Otel.Trace.Link` (api.md L803-L834) defines a Link as
  `context + attributes`. The `dropped_attributes_count` field
  is an SDK / wire-format concern (proto field 5 on
  `Span.Link`); placing it on the API struct would violate
  the API ↛ SDK layer-independence rule in
  `.claude/rules/code-conventions.md`.

  ## References

  - OTLP proto Span.Link:
    `opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto`
    L252-L290
  - OTel mapping spec:
    `opentelemetry-specification/specification/common/mapping-to-non-otlp.md`
    §"Dropped Attributes Count" L73-L80
  """

  use Otel.Common.Types

  @type t :: %__MODULE__{
          context: Otel.Trace.SpanContext.t(),
          attributes: %{String.t() => primitive_any()},
          dropped_attributes_count: non_neg_integer()
        }

  defstruct context: %Otel.Trace.SpanContext{},
            attributes: %{},
            dropped_attributes_count: 0
end
