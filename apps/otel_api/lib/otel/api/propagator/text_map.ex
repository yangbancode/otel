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
  dispatch. When unset, inject/extract act as no-ops (spec
  L322-L325 *"MUST use no-op propagators unless explicitly
  configured"*). The SDK does not pre-configure a default;
  callers install e.g. a composite of
  `Otel.API.Propagator.TextMap.TraceContext` +
  `Otel.API.Propagator.TextMap.Baggage` via
  `Otel.API.Propagator.TextMap.Composite.new/1`.

  ## Design notes

  Three places where we diverge from
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

  ### 3. `nil` as no-op rather than a concrete Noop module

  Spec L322-L325 mandates "no-op propagators" as the
  default. We implement that by returning `nil` from
  `get_propagator/0` and short-circuiting the facade when
  unset. A concrete `TextMap.Noop` module would be more
  OO-faithful but adds surface area for no behavioural gain.

  ## Public API

  | Function | Role |
  |---|---|
  | `@callback inject/3` | **OTel API MUST** — TextMap Inject (L155-L182) |
  | `@callback extract/3` | **OTel API MUST** — TextMap Extract (L185-L203); MUST NOT throw on parse failure (L100-L102) |
  | `@callback fields/0` | **OTel API** — Fields (L133-L152) |
  | `get_propagator/0` | **OTel API MUST** — Get Global Propagator (L334-L338) |
  | `set_propagator/1` | **OTel API MUST** — Set Global Propagator (L340-L346) |
  | `inject/3` | **OTel convenience** — Global facade |
  | `extract/3` | **OTel convenience** — Global facade |
  | `default_getter/2` | **W3C header parsing helper** — Getter.Get (L216-L225) |
  | `default_setter/3` | **W3C header serialization helper** — Setter.Set (L174-L186) |
  | `inject_with/4`, `extract_with/4` | **Local helper** — dispatch for `{module, opts}` vs atom |

  ## References

  - OTel Context §TextMap Propagator: `opentelemetry-specification/specification/context/api-propagators.md` L114-L203
  - OTel Context §Global Propagators: same file L308-L346
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_propagator_text_map.erl`
  """

  @global_key {__MODULE__, :global}

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
  **OTel API MUST** — TextMap "Inject" (`api-propagators.md`
  L155-L182).

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
  **OTel API MUST** — TextMap "Extract" (`api-propagators.md`
  L185-L203).

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
  **OTel API** — Fields (`api-propagators.md` L133-L152).

  Returns the list of header keys this propagator reads and
  writes. Used by carriers that want to pre-allocate or
  pre-clear fields before injection (L146-L149).
  """
  @callback fields() :: [String.t()]

  # --- Global propagator registration ---

  @doc """
  **OTel API MUST** — "Get Global Propagator"
  (`api-propagators.md` L334-L338).

  Returns the globally registered TextMap propagator, or
  `nil` if none is set. Per spec L322-L325 unconfigured
  state yields no-op behaviour; the nil return is our
  no-op signal (see `## Design notes` §3 in the
  `@moduledoc`).
  """
  @spec get_propagator() :: {module(), term()} | module() | nil
  def get_propagator do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  **OTel API MUST** — "Set Global Propagator"
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
  **OTel convenience** — inject via the global propagator
  (`api-propagators.md` L310-L313 *"Instrumentation
  libraries SHOULD call propagators to extract and inject
  the context on all remote calls"*).

  Dispatches to `get_propagator/0`'s current value.
  Returns `carrier` unchanged when no propagator is
  registered (no-op per spec L322-L325).

  `setter` defaults to `default_setter/3` for
  `[{String.t(), String.t()}]` carriers.
  """
  @spec inject(ctx :: Otel.API.Ctx.t(), carrier :: carrier(), setter :: setter()) :: carrier()
  def inject(ctx, carrier, setter \\ &default_setter/3) do
    case get_propagator() do
      nil -> carrier
      propagator -> inject_with(propagator, ctx, carrier, setter)
    end
  end

  @doc """
  **OTel convenience** — extract via the global propagator
  (`api-propagators.md` L310-L313).

  Dispatches to `get_propagator/0`'s current value.
  Returns `ctx` unchanged when no propagator is registered
  (no-op per spec L322-L325).

  `getter` defaults to `default_getter/2` for
  `[{String.t(), String.t()}]` carriers.
  """
  @spec extract(ctx :: Otel.API.Ctx.t(), carrier :: carrier(), getter :: getter()) ::
          Otel.API.Ctx.t()
  def extract(ctx, carrier, getter \\ &default_getter/2) do
    case get_propagator() do
      nil -> ctx
      propagator -> extract_with(propagator, ctx, carrier, getter)
    end
  end

  # --- Default carrier functions for [{String.t(), String.t()}] ---

  @doc """
  **W3C header parsing helper** — Getter.Get
  (`api-propagators.md` L216-L225) for
  `[{String.t(), String.t()}]` carriers.

  Case-insensitive key lookup returning the first matching
  value or `nil`. Spec L225 mandates case insensitivity for
  HTTP-like carriers.
  """
  @spec default_getter(carrier :: [{String.t(), String.t()}], key :: String.t()) ::
          String.t() | nil
  def default_getter(carrier, key) do
    lower_key = String.downcase(key)

    Enum.find_value(carrier, fn {k, v} ->
      if String.downcase(k) == lower_key, do: v
    end)
  end

  @doc """
  **W3C header serialization helper** — Setter.Set
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

  # --- Internal dispatch ---

  @doc """
  **Local helper** — dispatch the `{module, opts}` / atom
  propagator shape to the underlying module's `inject`.

  Not part of the user-facing API (users should call
  `inject/3` or rely on `Otel.API.Propagator.TextMap.Composite`
  to wrap sub-propagators). Exposed rather than `defp`
  because two modules need this same dispatch:

  - `inject/3` on this facade, when dispatching the global
    propagator retrieved from `get_propagator/0`.
  - `Otel.API.Propagator.TextMap.Composite.inject/4`,
    which loops over inner propagators of a composite.

  Dispatch rule:

  - Tuple `{module, opts}` → `module.inject(opts, ctx,
    carrier, setter)` (4-arity, for configured propagators
    like `Composite`).
  - Atom `module` → `module.inject(ctx, carrier, setter)`
    (3-arity, matches the `@callback inject/3` behaviour
    for single propagators like `TraceContext` and
    `Baggage`).
  """
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

  @doc """
  **Local helper** — dispatch counterpart of
  `inject_with/4` for extraction.

  Same design and caller set as `inject_with/4` (called
  from `extract/3` on this facade and from
  `Otel.API.Propagator.TextMap.Composite.extract/4`). Same
  tuple-vs-atom dispatch rule, applied to the module's
  `extract` callback.
  """
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
