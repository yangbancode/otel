defmodule Otel.API.Baggage.PercentTest do
  use ExUnit.Case, async: true

  describe "encode/1 — W3C §L65 RFC 3986 unreserved set" do
    test "passes the unreserved set through unchanged" do
      assert Otel.API.Baggage.Percent.encode("abcXYZ-._~123") == "abcXYZ-._~123"
      assert Otel.API.Baggage.Percent.encode("") == ""
    end

    test "encodes space, the percent character itself, and UTF-8 bytes" do
      assert Otel.API.Baggage.Percent.encode("hello world") == "hello%20world"
      assert Otel.API.Baggage.Percent.encode("50%") == "50%25"
      # "서울" = 0xEC 0x84 0x9C 0xEC 0x9A 0xB8
      assert Otel.API.Baggage.Percent.encode("서울") == "%EC%84%9C%EC%9A%B8"
    end
  end

  describe "decode/1" do
    test "inverse of encode/1 across ASCII, percent, and UTF-8" do
      assert Otel.API.Baggage.Percent.decode("abcXYZ-._~123") == "abcXYZ-._~123"
      assert Otel.API.Baggage.Percent.decode("hello%20world") == "hello world"
      assert Otel.API.Baggage.Percent.decode("50%25") == "50%"
      assert Otel.API.Baggage.Percent.decode("%EC%84%9C%EC%9A%B8") == "서울"
    end

    test "round-trips arbitrary UTF-8" do
      original = "name=김철수; role=admin; note=한국 🇰🇷"

      assert original |> Otel.API.Baggage.Percent.encode() |> Otel.API.Baggage.Percent.decode() ==
               original
    end
  end

  describe "decode/1 — W3C §L69 invalid UTF-8 replacement" do
    @replacement "�"

    test "single invalid byte → one U+FFFD" do
      # 0xFF is not a valid UTF-8 starter byte.
      assert Otel.API.Baggage.Percent.decode("%FF") == @replacement
    end

    test "multiple consecutive invalid bytes → one U+FFFD per byte" do
      assert Otel.API.Baggage.Percent.decode("%FF%FE") == @replacement <> @replacement
    end

    test "preserves valid ASCII / UTF-8 surrounding the invalid bytes" do
      # ASCII surround
      assert Otel.API.Baggage.Percent.decode("hello%FFworld") ==
               "hello" <> @replacement <> "world"

      # Multibyte surround: "서울" + 0xFF + "한"
      assert Otel.API.Baggage.Percent.decode("%EC%84%9C%EC%9A%B8%FF%ED%95%9C") ==
               "서울" <> @replacement <> "한"
    end

    test "incomplete trailing multibyte starter → U+FFFD" do
      # 0xC3 is a 2-byte starter with no continuation.
      assert Otel.API.Baggage.Percent.decode("%C3") == @replacement
    end

    test "result is always valid UTF-8 even on pathological input" do
      decoded = Otel.API.Baggage.Percent.decode("ok%FF%C3%80%FE%ED%95%9Cend")
      assert String.valid?(decoded)
    end
  end
end
