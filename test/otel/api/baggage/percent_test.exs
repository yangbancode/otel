defmodule Otel.API.Baggage.PercentTest do
  use ExUnit.Case, async: true

  describe "encode/1" do
    test "passes unreserved ASCII through unchanged" do
      assert Otel.API.Baggage.Percent.encode("abcXYZ-._~123") == "abcXYZ-._~123"
    end

    test "encodes space as %20" do
      assert Otel.API.Baggage.Percent.encode("hello world") == "hello%20world"
    end

    test "encodes the percent character itself (W3C §L65 MUST)" do
      assert Otel.API.Baggage.Percent.encode("50%") == "50%25"
    end

    test "encodes UTF-8 multibyte characters as their byte sequence" do
      # "서울" is 0xEC 0x84 0x9C 0xEC 0x9A 0xB8
      assert Otel.API.Baggage.Percent.encode("서울") == "%EC%84%9C%EC%9A%B8"
    end

    test "encodes an empty string as empty" do
      assert Otel.API.Baggage.Percent.encode("") == ""
    end
  end

  describe "decode/1" do
    test "passes unreserved ASCII through unchanged" do
      assert Otel.API.Baggage.Percent.decode("abcXYZ-._~123") == "abcXYZ-._~123"
    end

    test "decodes %20 to space" do
      assert Otel.API.Baggage.Percent.decode("hello%20world") == "hello world"
    end

    test "decodes %25 back to the percent character" do
      assert Otel.API.Baggage.Percent.decode("50%25") == "50%"
    end

    test "decodes UTF-8 multibyte sequences correctly" do
      assert Otel.API.Baggage.Percent.decode("%EC%84%9C%EC%9A%B8") == "서울"
    end

    test "round-trips arbitrary UTF-8" do
      original = "name=김철수; role=admin; note=한국 🇰🇷"
      encoded = Otel.API.Baggage.Percent.encode(original)
      assert Otel.API.Baggage.Percent.decode(encoded) == original
    end
  end

  describe "decode/1 — W3C §L69 invalid UTF-8 replacement" do
    @replacement "\uFFFD"

    test "replaces a single invalid byte with U+FFFD" do
      # 0xFF is not a valid UTF-8 starter byte
      assert Otel.API.Baggage.Percent.decode("%FF") == @replacement
    end

    test "replaces multiple consecutive invalid bytes, one U+FFFD per byte" do
      assert Otel.API.Baggage.Percent.decode("%FF%FE") == @replacement <> @replacement
    end

    test "preserves valid ASCII around invalid bytes" do
      # hello<0xFF>world — the 0xFF becomes U+FFFD, the rest survives
      assert Otel.API.Baggage.Percent.decode("hello%FFworld") ==
               "hello" <> @replacement <> "world"
    end

    test "preserves valid UTF-8 multibyte around invalid bytes" do
      # "서울" + 0xFF + "한" — valid-invalid-valid
      assert Otel.API.Baggage.Percent.decode("%EC%84%9C%EC%9A%B8%FF%ED%95%9C") ==
               "서울" <> @replacement <> "한"
    end

    test "replaces an incomplete trailing multibyte sequence" do
      # 0xC3 alone is a multibyte starter with no continuation
      assert Otel.API.Baggage.Percent.decode("%C3") == @replacement
    end

    test "result is always valid UTF-8" do
      # A pathological mix — every kind of ill-formedness
      decoded = Otel.API.Baggage.Percent.decode("ok%FF%C3%80%FE%ED%95%9Cend")
      assert String.valid?(decoded)
    end
  end
end
