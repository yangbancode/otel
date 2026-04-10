defmodule Otel.API.Trace.SpanKind do
  @moduledoc """
  SpanKind clarifies the relationship between Spans.

  Describes whether a span represents an incoming or outgoing call,
  and whether the communication is synchronous (request/response)
  or asynchronous (deferred execution).

  | SpanKind   | Call direction | Communication style |
  |------------|----------------|---------------------|
  | `:client`  | outgoing       | request/response    |
  | `:server`  | incoming       | request/response    |
  | `:producer`| outgoing       | deferred execution  |
  | `:consumer`| incoming       | deferred execution  |
  | `:internal`| —              | —                   |
  """

  @type t :: :internal | :server | :client | :producer | :consumer
end
