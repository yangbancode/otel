defmodule Otel.API.Trace.SpanKind do
  @moduledoc """
  SpanKind — clarifies the relationship between Spans (spec
  `trace/api.md` §SpanKind, Status: **Stable**).

  Describes two independent properties:

  - **Call direction**: outgoing (`:client` / `:producer`) vs
    incoming (`:server` / `:consumer`), or neither (`:internal`).
  - **Communication style**: request/response (`:client` /
    `:server`) vs deferred execution (`:producer` / `:consumer`).

  `:internal` is the spec default when a Span is created without
  an explicit kind (spec `trace/api.md` L397: *"default to
  `SpanKind.Internal` if not specified"*). That default is applied
  at Span creation, not by this type module.

  ## Values

  | SpanKind    | Call direction | Communication style |
  |-------------|----------------|---------------------|
  | `:client`   | outgoing       | request/response    |
  | `:server`   | incoming       | request/response    |
  | `:producer` | outgoing       | deferred execution  |
  | `:consumer` | incoming       | deferred execution  |
  | `:internal` | —              | — (default)         |

  ## References

  - OTel Trace API §SpanKind: `opentelemetry-specification/specification/trace/api.md` L741-L801
  """

  @typedoc """
  One of the five SpanKind atoms defined by OTel Trace API §SpanKind
  (`trace/api.md` L773-L791).

  - `:server` — server-side handling of a remote request while the
    client awaits a response (spec L775-L776).
  - `:client` — a request to a remote service where the client
    awaits a response; usually becomes a parent of a remote
    `:server` span when propagated (spec L777-L780).
  - `:producer` — initiation or scheduling of a local or remote
    operation; often ends before the correlated `:consumer` span
    (spec L781-L786).
  - `:consumer` — processing of an operation initiated by a
    producer, where the producer does not wait for the outcome
    (spec L787-L788).
  - `:internal` — default; internal operation within an
    application (spec L789-L791).
  """
  @type t :: :internal | :server | :client | :producer | :consumer
end
