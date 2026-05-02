defmodule Otel.SDK.Trace.Event do
  @moduledoc """
  SDK-internal representation of a Span Event.

  Mirrors the proto `Span.Event` message
  (`opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto`
  L222-L240) so the encoder can emit it 1:1, including the
  `dropped_attributes_count` field that the OTel
  `common/mapping-to-non-otlp.md` L75-L77 MUST requires per
  data entity.

  This struct is constructed by the SDK from the API-layer
  `Otel.API.Trace.Event` at the moment limits are applied
  (`Otel.SDK.Trace.Span.add_event/2`,
  `Otel.SDK.Trace.Span.start_span/6` for events provided at
  creation time). Application code should not construct
  this struct directly — use `Otel.API.Trace.Event.new/3`
  and pass the result to `Otel.API.Trace.Span.add_event/2`.

  ## Why a separate SDK type?

  `Otel.API.Trace.Event` (api.md L520-L558) defines an Event
  as `name + timestamp + attributes`. The `dropped_attributes_count`
  field is an SDK / wire-format concern (proto field 4 on
  `Span.Event`); placing it on the API struct would violate
  the API ↛ SDK layer-independence rule in
  `.claude/rules/code-conventions.md`.

  ## References

  - OTLP proto Span.Event:
    `opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto`
    L222-L240
  - OTel mapping spec:
    `opentelemetry-specification/specification/common/mapping-to-non-otlp.md`
    §"Dropped Attributes Count" L73-L80
  """

  use Otel.Common.Types

  @type t :: %__MODULE__{
          name: String.t(),
          timestamp: non_neg_integer(),
          attributes: %{String.t() => primitive_any()},
          dropped_attributes_count: non_neg_integer()
        }

  defstruct name: "", timestamp: 0, attributes: %{}, dropped_attributes_count: 0
end
