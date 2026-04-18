defmodule Otel.API.Propagator.Baggage do
  @moduledoc """
  W3C Baggage propagator.

  Implements inject and extract for the `baggage` header per the
  W3C Baggage specification.

  Header format: `key1=value1;metadata1,key2=value2;metadata2`

  Values are percent-encoded for safe HTTP transport.
  """

  @behaviour Otel.API.Propagator.TextMap

  @baggage_header "baggage"

  @impl true
  @spec inject(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          setter :: Otel.API.Propagator.TextMap.setter()
        ) :: Otel.API.Propagator.TextMap.carrier()
  def inject(ctx, carrier, setter) do
    baggage = Otel.API.Baggage.get_baggage(ctx)

    if map_size(baggage) > 0 do
      header_value = encode_baggage(baggage)
      setter.(@baggage_header, header_value, carrier)
    else
      carrier
    end
  end

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
        baggage = decode_baggage(String.trim(header_value))
        existing = Otel.API.Baggage.get_baggage(ctx)
        merged = Map.merge(existing, baggage)
        Otel.API.Baggage.set_baggage(ctx, merged)
    end
  end

  @impl true
  @spec fields() :: [String.t()]
  def fields, do: [@baggage_header]

  # --- Encoding ---

  @spec encode_baggage(baggage :: Otel.API.Baggage.t()) :: String.t()
  defp encode_baggage(baggage) do
    baggage
    |> Enum.map_join(",", fn {name, {value, metadata}} ->
      encoded_name = URI.encode_www_form(name)
      encoded_value = URI.encode_www_form(value)

      if metadata == "" do
        "#{encoded_name}=#{encoded_value}"
      else
        "#{encoded_name}=#{encoded_value};#{metadata}"
      end
    end)
  end

  # --- Decoding ---

  @spec decode_baggage(header :: String.t()) :: Otel.API.Baggage.t()
  defp decode_baggage(header) do
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

    {URI.decode_www_form(String.trim(name)), URI.decode_www_form(String.trim(value)), metadata}
  end
end
