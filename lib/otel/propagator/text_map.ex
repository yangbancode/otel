defmodule Otel.Propagator.TextMap do
  @moduledoc """
  TextMap propagator facade (OTel
  `context/api-propagators.md` §TextMap Propagator
  L114-L203; §Composite Propagator L259-L305).

  A `TextMapPropagator` injects cross-cutting-concern values
  into and extracts them from carriers — typically HTTP
  headers — as string key/value pairs. Carriers are
  accessed through `getter`/`setter` functions so the
  propagator avoids wrapper-object allocations (spec
  L127-L132).

  Per spec L122-L124, key/value pairs MUST consist of
  US-ASCII characters that make up valid HTTP header fields
  per RFC 9110. Enforcement is the caller's responsibility.

  ## Hardcoded propagator list

  This module hardcodes the propagator list to
  `[Otel.Propagator.TextMap.TraceContext,
  Otel.Propagator.TextMap.Baggage]` — the OTel default per
  `sdk-environment-variables.md` L118 (`OTEL_PROPAGATORS`
  default `"tracecontext,baggage"`) and
  `context/api-propagators.md` L329-L331. There is no global
  registration slot and no Composite wrapper; `inject/3` and
  `extract/3` iterate the list directly.

  Power users wanting B3 / Jaeger / X-Ray propagators should
  use `opentelemetry-erlang`.

  ## Public API

  | Function | Role |
  |---|---|
  | `inject/3` | **Application** (OTel API SHOULD) — inject via the hardcoded propagator list (L310-L313) |
  | `extract/3` | **Application** (OTel API SHOULD) — extract via the hardcoded propagator list (L310-L313) |
  | `default_getter/2` | **Application** (W3C header parsing) — Getter.Get (L216-L225) for `[{String.t(), String.t()}]` carriers |
  | `default_setter/3` | **Application** (W3C header serialization) — Setter.Set (L174-L186) for `[{String.t(), String.t()}]` carriers |

  ## References

  - OTel Context §TextMap Propagator: `opentelemetry-specification/specification/context/api-propagators.md` L114-L203
  - OTel Context §Composite Propagator: same file L259-L305
  - OTel Context §Global Propagators: same file L308-L346
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_propagator_text_map.erl`
  """

  @propagators [
    Otel.Propagator.TextMap.TraceContext,
    Otel.Propagator.TextMap.Baggage
  ]

  @typedoc "A generic carrier — typically a list of HTTP header tuples."
  @type carrier :: term()

  @typedoc """
  A function that reads the first value for a key from the
  carrier (spec §Getter.Get L216-L225). Returns `nil` when
  the key is absent. For HTTP-like carriers the getter MUST
  be case-insensitive (L225).
  """
  @type getter :: (carrier(), key :: String.t() -> String.t() | nil)

  @typedoc """
  A function that writes a key/value pair into the carrier
  (spec §Setter.Set L174-L186). SHOULD preserve the supplied
  key casing per L186.
  """
  @type setter :: (key :: String.t(), value :: String.t(), carrier() -> carrier())

  @doc """
  **Application** (OTel API SHOULD) — inject via the
  hardcoded propagator list (`api-propagators.md` L310-L313
  *"Instrumentation libraries SHOULD call propagators to
  extract and inject the context on all remote calls"*).

  Threads `carrier` through each configured propagator's
  `inject/3` in order so all propagators write to the same
  carrier (spec §Composite Inject L297-L305).

  `setter` defaults to `default_setter/3` for
  `[{String.t(), String.t()}]` carriers.
  """
  @spec inject(ctx :: Otel.Ctx.t(), carrier :: carrier(), setter :: setter()) :: carrier()
  def inject(ctx, carrier, setter \\ &default_setter/3) do
    Enum.reduce(@propagators, carrier, fn module, acc ->
      module.inject(ctx, acc, setter)
    end)
  end

  @doc """
  **Application** (OTel API SHOULD) — extract via the
  hardcoded propagator list (`api-propagators.md` L310-L313).

  Threads `ctx` through each configured propagator's
  `extract/3` in order so later propagators see earlier
  extractions (spec §Composite Extract L286-L296).

  `getter` defaults to `default_getter/2` for
  `[{String.t(), String.t()}]` carriers.
  """
  @spec extract(ctx :: Otel.Ctx.t(), carrier :: carrier(), getter :: getter()) ::
          Otel.Ctx.t()
  def extract(ctx, carrier, getter \\ &default_getter/2) do
    Enum.reduce(@propagators, ctx, fn module, acc_ctx ->
      module.extract(acc_ctx, carrier, getter)
    end)
  end

  @doc """
  **Application** (W3C header parsing) — Getter for
  `[{String.t(), String.t()}]` carriers (`api-propagators.md`
  §Get L221-L230 + §GetAll L232-L249).

  Case-insensitive key lookup. Returns `nil` when no
  matching entry exists; for a single match, returns the
  value as-is; for multiple matching entries, returns their
  values joined with `","`.

  ## Intentional divergence from spec §Get L223

  Spec L223: *"The Get function MUST return the first value
  of the given propagation key or return null if the key
  doesn't exist."* Strictly read, our behaviour on multiple
  matches violates this MUST — we combine instead of
  returning the first.

  We diverge because **the spec's §Get vs §GetAll split is
  the wrong abstraction for HTTP carriers**:

  - Per RFC 9110 §5.3 *"a recipient MAY combine multiple
    instances of a list-based field into one field-value, by
    appending each subsequent value to the combined value
    using a comma"*. Combination is the canonical recipient
    operation for list-based fields.
  - Both W3C Baggage L6 (*"Multiple `baggage` headers are
    allowed. Values can be combined in a single header
    according to RFC 7230"*) and W3C TraceContext §3.3.1.5
    (*"multiple `tracestate` headers ... combined into one"*)
    are list-based fields that REQUIRE combination for
    correct extraction.
  - Returning only the first value here would silently drop
    list-members from any carrier that preserved the raw
    split form (e.g. `:cowboy_req:headers/1`), corrupting
    downstream W3C parsing.

  In other words, the spec's §Get-only contract is wrong for
  HTTP list-field extraction; honouring it strictly would
  break tracestate / baggage interop. The combined-result
  behaviour is decoded correctly by downstream parsers
  regardless of OWS per the W3C grammars
  (`list-member 0*179( OWS "," OWS list-member )`) and
  matches what `encode_baggage/1` would emit on inject.

  Callers needing strict §Get semantics (first-only) can
  supply a custom getter to `extract/3`. We keep the default
  combined-result behaviour because it is what the in-tree
  W3C propagators (`text_map/baggage.ex`,
  `text_map/trace_context.ex`) need.

  Spec L230 mandates case-insensitive matching for
  HTTP-like carriers; that part is honoured.
  """
  @spec default_getter(carrier :: [{String.t(), String.t()}], key :: String.t()) ::
          String.t() | nil
  def default_getter(carrier, key) do
    lower_key = String.downcase(key)

    case Enum.filter(carrier, fn {k, _v} -> String.downcase(k) == lower_key end) do
      [] -> nil
      [{_k, v}] -> v
      matches -> Enum.map_join(matches, ",", fn {_k, v} -> v end)
    end
  end

  @doc """
  **Application** (W3C header serialization) — Setter.Set
  (`api-propagators.md` L174-L186) for
  `[{String.t(), String.t()}]` carriers.

  Implements spec's *"Replaces a propagated field with the
  given value"* (L178) together with the casing rule at
  L186. Two behaviours to notice:

  - **Matching existing entries** — the carrier is scanned
    case-insensitively and any entry whose key matches the
    supplied `key` is removed before the new pair is
    appended. Spec §Setter.Set does not literally mandate
    case-insensitive matching, but HTTP header names are
    case-insensitive per RFC 9110 and `[{String.t(),
    String.t()}]` carriers are HTTP-like, so matching
    case-insensitively is the only way to honour spec's
    "Replaces" without leaving duplicate headers behind.

  - **Casing preservation on write** — the supplied `key`
    is written to the carrier as-is, satisfying spec L186
    *"The implementation SHOULD preserve casing"* for
    case-insensitive protocols (MUST for case-sensitive
    ones).
  """
  @spec default_setter(
          key :: String.t(),
          value :: String.t(),
          carrier :: [{String.t(), String.t()}]
        ) ::
          [{String.t(), String.t()}]
  def default_setter(key, value, carrier) do
    lower_key = String.downcase(key)
    filtered = Enum.reject(carrier, fn {k, _v} -> String.downcase(k) == lower_key end)
    filtered ++ [{key, value}]
  end
end
