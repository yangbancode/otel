defmodule Otel.API.Attributes do
  @moduledoc """
  Attribute collection — a map from keys to values.

  This module defines only the collection type (`t/0`). For the
  single-attribute types (`key`, `scalar`, `value`) see
  `Otel.API.Attribute`. The split mirrors the spec's distinction between
  a single attribute and an attribute collection, and matches the
  convention used in other OTel SDKs (Java's `AttributeKey` vs
  `Attributes`, Go's `attribute.Key` vs `attribute.Set`).

  ## Collection — `t/0`

  The collection is a plain map:

      %{Attribute.key() => Attribute.value()}

  Keyword lists (`[{key, value}]`) are not accepted. A map guarantees
  unique keys by construction, which satisfies the spec's "MUST enforce
  unique keys" rule without a runtime validation pass.

  This module currently defines types only. Count and value-length limits
  are applied at the container level — see
  `Otel.SDK.Trace.Span.apply_attribute_limits/3` — because OTLP exposes
  `dropped_attributes_count` per container (Span, Event, Link, LogRecord),
  not per attribute collection. Keeping attributes as a pure map avoids
  leaking container policy into the data type.
  """

  @typedoc """
  A collection of attributes.

  Always a map from `Otel.API.Attribute.key/0` to `Otel.API.Attribute.value/0`.
  Keyword lists are not accepted — the map representation guarantees
  unique keys, satisfying the spec without runtime validation.
  """
  @type t :: %{Otel.API.Attribute.key() => Otel.API.Attribute.value()}
end
