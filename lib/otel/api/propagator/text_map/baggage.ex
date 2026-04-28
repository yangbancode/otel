defmodule Otel.API.Propagator.TextMap.Baggage do
  @moduledoc """
  W3C Baggage propagator (W3C `HTTP_HEADER_FORMAT.md` §Header
  Content L19-L113; OTel `context/api-propagators.md`
  §TextMap Inject/Extract L155-L203).

  Injects and extracts the `baggage` HTTP header. Wire format
  per W3C §Definition L23-L41 (ABNF):

      baggage-string = list-member 0*179( OWS "," OWS list-member )
      list-member    = key OWS "=" OWS value *( OWS ";" OWS property )

  Example header value:

      userId=abc123,serverNode=node-42;region=us-east

  ## Design notes

  Five places worth calling out — three intentional
  divergences from `opentelemetry-erlang`'s
  `otel_propagator_baggage.erl`, one spec alignment that
  Erlang has not yet made, and one acknowledged W3C-token
  divergence on the wire. Each is documented so future
  readers can see where we stand.

  ### 1. Strict RFC 3986 percent-encoding with U+FFFD replacement

  W3C §value L64-L68 requires RFC 3986 percent-encoding.
  Per §Definition L32, `baggage-octet` explicitly includes
  `+` (0x2B) as a valid raw character, so `+` in a value
  MUST mean literal plus — not an encoded space.

  Encoding and decoding are delegated to
  `Otel.API.Baggage.Percent`, which also implements the §L69
  MUST that percent-encoded octet sequences not matching
  UTF-8 must be replaced with `U+FFFD`. Inject produces
  `%20` for space; extract decodes `%20` to space and leaves
  `+` as literal, preserving round-trip fidelity.

  `opentelemetry-erlang` (`otel_propagator_baggage.erl`
  L146-L147) still uses `form_urlencode` with a `TODO: call
  uri_string:percent_encode` comment — its encoder emits `+`
  for space while its decoder treats `+` as literal, which
  loses round-trip fidelity for space-containing values and
  conflates `+` semantics. We do not mirror that limitation.

  ### 2. Metadata as opaque string

  `Otel.API.Baggage` stores each entry's metadata as a single
  string (`{value, metadata}`). W3C §property L82-L100 defines
  a structured property list (e.g. `;k1=v1;k2;k3=v3`), and
  `opentelemetry-erlang` parses it into a list of key/value
  tuples with per-property percent-encoding.

  This propagator round-trips the raw metadata string
  byte-for-byte — no splitting on `;`, no per-property
  percent-encoding. The choice mirrors `Otel.API.Baggage`'s
  opaque-metadata design; callers who need structured
  metadata parse it themselves.

  ### 3. Extract merges with existing baggage

  `opentelemetry-erlang` replaces the context's baggage with
  what the header carries (`otel_baggage:set_to`). We merge:
  entries in the incoming header overwrite same-key entries
  in the context, but entries only present in the context
  are preserved.

  Neither behaviour is mandated — W3C governs only the wire
  format, and OTel L108-L114 says the returned context
  "contains the extracted value" without prescribing how it
  combines with pre-existing values. Merge serves the common
  pattern of "local annotation + received baggage flowing
  together".

  ### 4. W3C Limits not enforced at the propagator layer

  W3C §Limits L102-L113 mandates propagating all list-members
  when the result is ≤64 entries and ≤8192 bytes, and allows
  (MAY) dropping entries otherwise. We always emit every
  entry present in `Baggage.current/1`. Neither the MUST
  (trivially satisfied for small baggage) nor the MAY
  (optional) requires defensive limits here; if limits become
  necessary they belong in `Otel.API.Baggage`'s mutation
  surface, not the wire-format propagator.

  ### 5. Key encoding over-encodes RFC 7230 token characters

  W3C `HTTP_HEADER_FORMAT.md` L52-L53 says baggage *names*
  are RFC 7230 `token` values. RFC 7230 §3.2.6 `tchar`
  permits sub-delim characters (`!`, `#`, `$`, `&`, `'`, `*`,
  `+`, `-`, `.`, `^`, `_`, `` ` ``, `|`, `~`) in addition to
  ALPHA/DIGIT — so a key like `user.id` or `user!id` is a
  valid `token`.

  `Otel.API.Baggage.Percent.encode/1` percent-encodes
  everything outside `URI.char_unreserved?/1` (`A-Z`, `a-z`,
  `0-9`, `-`, `.`, `_`, `~`). That is RFC 3986 strict — but
  it over-encodes the token sub-delims. A key like
  `user!id` injects as `user%21id`, which a strict W3C parser
  reading the wire format may reject because `%21id` is not a
  `token`. OTel peers (which decode percent escapes before
  comparing) are unaffected — they recover the original
  `user!id` and round-trip correctly.

  We accept the over-encoding because it gives a single
  encode pipeline shared with values (where RFC 3986 is the
  right answer per W3C §value L64-L68) and because the
  alternative — restricting to RFC 7230 token chars and
  rejecting non-token keys — would either silently drop user
  baggage or require a separate encoder. Strict W3C
  interoperability for non-token keys can be added in a
  follow-up; today the trade-off is "over-encoded keys
  round-trip with OTel peers, may be rejected by strict
  non-OTel parsers".

  ## Public API

  | Function | Role |
  |---|---|
  | `inject/3` | **SDK** (OTel API MUST) — TextMap Inject (L155-L182); `@impl Otel.API.Propagator.TextMap` |
  | `extract/3` | **SDK** (OTel API MUST) — TextMap Extract (L185-L203); MUST NOT throw on parse failure (L102) |
  | `fields/0` | **SDK** (OTel API MUST) — Fields (L133-L152) |
  | `encode_baggage/1` | **Application** (W3C header serialization) — §Definition L23-L41 |
  | `decode_baggage/1` | **Application** (W3C header parsing) — §Definition L23-L41 |

  ## References

  - W3C Baggage HTTP Header: `w3c-baggage/baggage/HTTP_HEADER_FORMAT.md` L1-L180
  - OTel Context §TextMap Propagator: `opentelemetry-specification/specification/context/api-propagators.md` L114-L203
  - OTel Context §Extract MUST NOT throw: `opentelemetry-specification/specification/context/api-propagators.md` L100-L102
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_propagator_baggage.erl`
  """

  @behaviour Otel.API.Propagator.TextMap

  @baggage_header "baggage"

  @doc """
  **SDK** (OTel API MUST) — TextMap "Inject"
  (`api-propagators.md` L155-L182) for the W3C `baggage`
  header.

  Serialises `Otel.API.Baggage.current(ctx)` into a single
  comma-separated `baggage` header value and sets it on the
  carrier. When the context's baggage is empty the carrier is
  returned unchanged (no header written).
  """
  @impl true
  @spec inject(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          setter :: Otel.API.Propagator.TextMap.setter()
        ) :: Otel.API.Propagator.TextMap.carrier()
  def inject(ctx, carrier, setter) do
    baggage = Otel.API.Baggage.current(ctx)

    if map_size(baggage) > 0 do
      header_value = encode_baggage(baggage)
      setter.(@baggage_header, header_value, carrier)
    else
      carrier
    end
  end

  @doc """
  **SDK** (OTel API MUST) — TextMap "Extract"
  (`api-propagators.md` L185-L203) for the W3C `baggage`
  header.

  Parses the `baggage` header into `{value, metadata}` pairs
  and merges the result into `Otel.API.Baggage.current(ctx)`
  (see "Extract merges with existing baggage" in the module
  docs).

  Per spec L100-L102 **MUST NOT throw on parse failure** —
  malformed input (missing `=`, garbage bytes, encoding
  errors, etc.) causes the original context to be returned
  unchanged via a `catch _, _` clause that covers all three
  exit kinds (`:error`, `:throw`, `:exit`) so any abnormal
  exit from the parsing pipeline is swallowed. This is an
  explicit exception to the project's happy-path policy,
  listed under "Not error handling" in
  `.claude/rules/code-conventions.md`.
  """
  @impl true
  @spec extract(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Ctx.t()
  def extract(ctx, carrier, getter) do
    case getter.(carrier, @baggage_header) do
      nil ->
        ctx

      header_value ->
        try do
          baggage = decode_baggage(String.trim(header_value))
          existing = Otel.API.Baggage.current(ctx)
          merged = Map.merge(existing, baggage)
          Otel.API.Baggage.set_current(ctx, merged)
        catch
          _, _ -> ctx
        end
    end
  end

  @doc """
  **SDK** (OTel API MUST) — "Fields" (`api-propagators.md`
  L133-L152).

  Returns `["baggage"]` — the single header name this
  propagator reads and writes.
  """
  @impl true
  @spec fields() :: [String.t()]
  def fields, do: [@baggage_header]

  # --- Encoding ---

  @doc """
  **Application** (W3C header serialization) — encodes an
  `Otel.API.Baggage.t()` map into a `baggage` header value.

  Produces a comma-separated list of `list-member`s per W3C
  §Definition L23-L41 (ABNF). Each entry's name and value
  are RFC 3986 percent-encoded (§value L64-L68); metadata
  is written verbatim (see the module's `## Design notes`
  §2 for the opaque-metadata rationale).

  Returns `""` for an empty baggage map. The `inject/3`
  caller uses that as the signal not to emit the header.
  """
  @spec encode_baggage(baggage :: Otel.API.Baggage.t()) :: String.t()
  def encode_baggage(baggage) do
    baggage
    |> Enum.map_join(",", fn {name, {value, metadata}} ->
      encoded_name = Otel.API.Baggage.Percent.encode(name)
      encoded_value = Otel.API.Baggage.Percent.encode(value)

      if metadata == "" do
        "#{encoded_name}=#{encoded_value}"
      else
        "#{encoded_name}=#{encoded_value};#{metadata}"
      end
    end)
  end

  # --- Decoding ---

  @doc """
  **Application** (W3C header parsing) — decodes a `baggage`
  header value into an `Otel.API.Baggage.t()` map.

  Splits the header on `,` into `list-member`s per W3C
  §Definition L23-L41, delegates each to `decode_entry/1`,
  and builds the baggage map. Name and value are RFC 3986
  percent-decoded (§value L69); metadata is kept verbatim.

  Raises (typically `MatchError`) if any `list-member` is
  malformed — for example a pair without `=`. Callers that
  need the spec-mandated graceful recovery
  (`api-propagators.md` L100-L102 "MUST NOT throw on parse
  failure") should go through `extract/3`, which wraps this
  call in a `catch` clause.
  """
  @spec decode_baggage(header :: String.t()) :: Otel.API.Baggage.t()
  def decode_baggage(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(%{}, fn pair, acc ->
      {name, value, metadata} = decode_entry(pair)
      Map.put(acc, name, {value, metadata})
    end)
  end

  @spec decode_entry(pair :: String.t()) :: {String.t(), String.t(), String.t()}
  defp decode_entry(pair) do
    {key_value, metadata} =
      case String.split(pair, ";", parts: 2) do
        [kv, meta] -> {kv, String.trim(meta)}
        [kv] -> {kv, ""}
      end

    [name, value] = String.split(String.trim(key_value), "=", parts: 2)

    {Otel.API.Baggage.Percent.decode(String.trim(name)),
     Otel.API.Baggage.Percent.decode(String.trim(value)), metadata}
  end
end
