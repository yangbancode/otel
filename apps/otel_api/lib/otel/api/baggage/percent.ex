defmodule Otel.API.Baggage.Percent do
  @moduledoc """
  W3C Baggage percent-encoding codec (W3C Baggage spec
  §value L64-L69, §property L82-L100).

  Percent-encodes / decodes UTF-8 strings for use in the
  W3C Baggage wire format. Values outside the
  `baggage-octet` character range (defined in §Definition)
  must be percent-encoded:

      baggage-octet = %x21 / %x23-2B / %x2D-3A /
                      %x3C-5B / %x5D-7E

  On decode, percent-encoded octet sequences that do not
  form valid UTF-8 are replaced with the Unicode
  replacement character `U+FFFD`, per §L69 MUST:

  > *"When decoding the value, percent-encoded octet
  > sequences that do not match the UTF-8 encoding scheme
  > MUST be replaced with the replacement code point
  > (`U+FFFD`)."*

  Replacement is performed one invalid byte at a time —
  offending bytes are replaced without dropping the rest
  of the string, so a single malformed value does not
  discard the whole baggage list.

  ## Callers

  - `Otel.API.Propagator.TextMap.Baggage` — HTTP
    `baggage:` header value/property encoding
  - `Otel.SDK.Resource` — OTEL_RESOURCE_ATTRIBUTES
    environment variable parsing (same Baggage-like
    format per `resource/sdk.md`)

  ## References

  - W3C Baggage §value: `w3c-baggage/baggage/HTTP_HEADER_FORMAT.md` L61-L80
  - W3C Baggage §property: `w3c-baggage/baggage/HTTP_HEADER_FORMAT.md` L82-L100
  - RFC 3986 §2.1 Percent-Encoding: <https://datatracker.ietf.org/doc/html/rfc3986#section-2.1>
  """

  @replacement "\uFFFD"

  @doc """
  **W3C header serialization** — percent-encodes a UTF-8
  string per W3C Baggage §value L64-L68.

  Emits RFC 3986 Section 2.1 percent-encoding over the
  `URI.char_unreserved?/1` predicate. The unreserved set
  (`A-Z / a-z / 0-9 / - . _ ~`) is a strict subset of
  `baggage-octet`, so we percent-encode more conservatively
  than the spec MUSTs. W3C §L66 explicitly permits this:

  > *"Code points which are not required to be
  > percent-encoded MAY be percent-encoded."*

  Space (`0x20`) encodes as `%20`, matching the baggage-
  octet encoding of whitespace. The percent character
  `0x25` itself is also encoded per §L65 MUST.
  """
  @spec encode(value :: String.t()) :: String.t()
  def encode(value), do: URI.encode(value, &URI.char_unreserved?/1)

  @doc """
  **W3C header parsing** — percent-decodes a string per
  W3C Baggage §value L69.

  Decodes RFC 3986 Section 2.1 percent sequences. Any
  decoded octet sequence that is not valid UTF-8 is
  replaced with `U+FFFD` per §L69 MUST — offending bytes
  only, preserving the rest of the string.
  """
  @spec decode(encoded :: String.t()) :: String.t()
  def decode(encoded) do
    encoded
    |> URI.decode()
    |> replace_invalid_utf8()
  end

  @spec replace_invalid_utf8(binary :: binary()) :: String.t()
  defp replace_invalid_utf8(binary) do
    case :unicode.characters_to_binary(binary, :utf8, :utf8) do
      result when is_binary(result) ->
        result

      {:error, good, <<_invalid, rest::binary>>} ->
        good <> @replacement <> replace_invalid_utf8(rest)

      {:incomplete, good, _trailing} ->
        good <> @replacement
    end
  end
end
