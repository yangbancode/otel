defmodule Otel.API.Propagator.TextMap do
  @moduledoc """
  `TextMapPropagator` behaviour and global facade (OTel
  `context/api-propagators.md` §TextMap Propagator
  L114-L203; §Global Propagators L308-L346).

  A `TextMapPropagator` injects cross-cutting-concern values
  into and extracts them from carriers — typically HTTP
  headers — as string key/value pairs. Carriers are
  accessed through `getter`/`setter` functions so the
  propagator avoids wrapper-object allocations (spec
  L127-L132).

  Per spec L122-L124, key/value pairs MUST consist of
  US-ASCII characters that make up valid HTTP header fields
  per RFC 9110. Enforcement is the caller's responsibility.

  ## Global propagator registration

  The API owns a single global TextMapPropagator slot stored
  in `:persistent_term`. `set_propagator/1` registers,
  `get_propagator/0` reads, `inject/3` and `extract/3`
  dispatch. When unset, `get_propagator/0` returns
  `Otel.API.Propagator.TextMap.Noop`, satisfying spec
  L322-L325 *"The OpenTelemetry API MUST use no-op
  propagators unless explicitly configured otherwise"*. The
  SDK does not pre-configure a default; callers install e.g.
  a composite of `Otel.API.Propagator.TextMap.TraceContext` +
  `Otel.API.Propagator.TextMap.Baggage` via
  `Otel.API.Propagator.TextMap.Composite.new/1`.

  ## Design notes

  Two places where we diverge from
  `opentelemetry-erlang`'s `otel_propagator_text_map.erl`.

  ### 1. 3-arity behaviour (no options parameter)

  Erlang's callback is 4-arity for `inject` and 5-arity for
  `extract`, with a trailing `propagator_options()`. We use
  3-arity with no options at the behaviour level.
  Configured propagators (currently only
  `Otel.API.Propagator.TextMap.Composite`) are dispatched
  via a `{module, opts}` tuple pattern matched by
  `inject_with/4` / `extract_with/4`; the opts then flow as
  the first argument to the module's own 4-arity inject /
  extract functions. This keeps single-header propagators
  (TraceContext, Baggage) free of an unused options
  parameter.

  ### 2. No `Keys` callback / `GetAll` helper

  Spec §Keys (L219-L222) and §GetAll (L240-L252) describe
  multi-value / variable-key Getter methods primarily useful
  for propagators with dynamic header patterns (e.g. B3
  multi-header `X-B3-*`). This project supports only W3C
  TraceContext and W3C Baggage, both single-header
  single-value formats, and does not support B3. The
  behaviour omits Keys, and the module does not provide
  `default_keys/1` / `default_get_all/2` helpers.

  ## Public API

  | Function | Role |
  |---|---|
  | `inject/3` | **Application** (OTel API SHOULD) — global-propagator inject (L310-L313) |
  | `extract/3` | **Application** (OTel API SHOULD) — global-propagator extract (L310-L313) |
  | `get_propagator/0` | **Application** (OTel API MUST) — Get Global Propagator (L334-L338) |
  | `set_propagator/1` | **Application** (OTel API MUST) — Set Global Propagator (L340-L346) |
  | `default_getter/2` | **Application** (W3C header parsing) — Getter.Get (L216-L225) for `[{String.t(), String.t()}]` carriers |
  | `default_setter/3` | **Application** (W3C header serialization) — Setter.Set (L174-L186) for `[{String.t(), String.t()}]` carriers |
  | `@callback inject/3` | **SDK** (OTel API MUST) — TextMap Inject (L155-L182) |
  | `@callback extract/3` | **SDK** (OTel API MUST) — TextMap Extract (L185-L203); MUST NOT throw on parse failure (L100-L102) |
  | `@callback fields/0` | **SDK** (OTel API MUST) — Fields (L133-L152) |

  ## References

  - OTel Context §TextMap Propagator: `opentelemetry-specification/specification/context/api-propagators.md` L114-L203
  - OTel Context §Global Propagators: same file L308-L346
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_propagator_text_map.erl`

  ## Spec verification

  Verified against `opentelemetry-specification` v1.55.0
  (commit `9e23700`) on 2026-04-27. Re-verify after any
  submodule advance — see `.claude/rules/workflow.md`
  § Spec submodule update.
  """

  @global_key {__MODULE__, :global}

  @default_propagator Otel.API.Propagator.TextMap.Noop

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

  # --- Application dispatch ---

  @doc """
  **Application** (OTel API MUST) — "Get Global Propagator"
  (`api-propagators.md` L334-L338).

  Returns the globally registered TextMap propagator. When no
  propagator has been installed via `set_propagator/1`,
  returns `Otel.API.Propagator.TextMap.Noop`, satisfying spec
  L322-L325 *"MUST use no-op propagators unless explicitly
  configured otherwise"*.

  Callers can pass the result directly to `inject_with/4` /
  `extract_with/4` without nil-checking — the Noop
  implementation is spec-conformant and always present.
  """
  @spec get_propagator() :: {module(), term()} | module()
  def get_propagator do
    :persistent_term.get(@global_key, @default_propagator)
  end

  @doc """
  **Application** (OTel API MUST) — "Set Global Propagator"
  (`api-propagators.md` L340-L346).

  Registers a propagator as the global TextMap propagator.
  Accepts either an atom module (for single-header
  propagators like `TextMap.TraceContext`) or a
  `{module, opts}` tuple (for configured propagators like
  `TextMap.Composite` produced by
  `Otel.API.Propagator.TextMap.Composite.new/1`).
  """
  @spec set_propagator(propagator :: {module(), term()} | module()) :: :ok
  def set_propagator(propagator) do
    :persistent_term.put(@global_key, propagator)
    :ok
  end

  # --- Convenience facade using the global propagator ---

  @doc """
  **Application** (OTel API SHOULD) — inject via the global
  propagator (`api-propagators.md` L310-L313 *"Instrumentation
  libraries SHOULD call propagators to extract and inject
  the context on all remote calls"*).

  Dispatches to `get_propagator/0`'s current value. When no
  propagator is installed the Noop default returns the
  carrier unchanged (spec L322-L325).

  `setter` defaults to `default_setter/3` for
  `[{String.t(), String.t()}]` carriers.
  """
  @spec inject(ctx :: Otel.API.Ctx.t(), carrier :: carrier(), setter :: setter()) :: carrier()
  def inject(ctx, carrier, setter \\ &default_setter/3) do
    inject_with(get_propagator(), ctx, carrier, setter)
  end

  @doc """
  **Application** (OTel API SHOULD) — extract via the global
  propagator (`api-propagators.md` L310-L313).

  Dispatches to `get_propagator/0`'s current value. When no
  propagator is installed the Noop default returns the
  context unchanged (spec L322-L325).

  `getter` defaults to `default_getter/2` for
  `[{String.t(), String.t()}]` carriers.
  """
  @spec extract(ctx :: Otel.API.Ctx.t(), carrier :: carrier(), getter :: getter()) ::
          Otel.API.Ctx.t()
  def extract(ctx, carrier, getter \\ &default_getter/2) do
    extract_with(get_propagator(), ctx, carrier, getter)
  end

  # --- Default carrier functions for [{String.t(), String.t()}] ---

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

  # --- SDK callbacks ---

  @doc """
  **SDK** (OTel API MUST) — TextMap "Inject"
  (`api-propagators.md` L155-L182).

  Implementations inject cross-cutting-concern values from
  `ctx` into `carrier` via `setter`. The setter MAY be
  invoked multiple times for multi-field propagators
  (L168-L169).
  """
  @callback inject(
              ctx :: Otel.API.Ctx.t(),
              carrier :: carrier(),
              setter :: setter()
            ) :: carrier()

  @doc """
  **SDK** (OTel API MUST) — TextMap "Extract"
  (`api-propagators.md` L185-L203).

  Implementations read values out of `carrier` via `getter`
  and return a new `Context` derived from `ctx` with the
  extracted value. Per spec L100-L102 the implementation
  **MUST NOT throw** on parse failure and **MUST NOT store a
  new value** — malformed carriers yield the original `ctx`
  unchanged.
  """
  @callback extract(
              ctx :: Otel.API.Ctx.t(),
              carrier :: carrier(),
              getter :: getter()
            ) :: Otel.API.Ctx.t()

  @doc """
  **SDK** (OTel API MUST) — Fields (`api-propagators.md`
  L133-L152).

  Returns the list of header keys this propagator reads and
  writes. Used by carriers that want to pre-allocate or
  pre-clear fields before injection (L146-L149).
  """
  @callback fields() :: [String.t()]

  # --- Internal dispatch ---

  # Internal: cross-module helper called by this facade's
  # `inject/3` and by `Otel.API.Propagator.TextMap.Composite.inject/4`
  # (which loops over inner propagators of a composite).
  # Dispatches the `{module, opts}` vs atom propagator shape:
  #
  # - Tuple `{module, opts}` → `module.inject(opts, ctx,
  #   carrier, setter)` (4-arity, for configured propagators
  #   like `Composite`).
  # - Atom `module` → `module.inject(ctx, carrier, setter)`
  #   (3-arity, matches the `@callback inject/3` behaviour
  #   for single propagators like `TraceContext` and
  #   `Baggage`).
  @doc false
  @spec inject_with(
          propagator :: {module(), term()} | module(),
          ctx :: Otel.API.Ctx.t(),
          carrier :: carrier(),
          setter :: setter()
        ) :: carrier()
  def inject_with({module, opts}, ctx, carrier, setter) do
    module.inject(opts, ctx, carrier, setter)
  end

  def inject_with(module, ctx, carrier, setter) do
    module.inject(ctx, carrier, setter)
  end

  # Internal: dispatch counterpart of `inject_with/4` for
  # extraction. Called from this facade's `extract/3` and from
  # `Otel.API.Propagator.TextMap.Composite.extract/4`. Same
  # tuple-vs-atom dispatch rule, applied to the module's
  # `extract` callback.
  @doc false
  @spec extract_with(
          propagator :: {module(), term()} | module(),
          ctx :: Otel.API.Ctx.t(),
          carrier :: carrier(),
          getter :: getter()
        ) :: Otel.API.Ctx.t()
  def extract_with({module, opts}, ctx, carrier, getter) do
    module.extract(opts, ctx, carrier, getter)
  end

  def extract_with(module, ctx, carrier, getter) do
    module.extract(ctx, carrier, getter)
  end
end
