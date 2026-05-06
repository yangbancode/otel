defmodule Otel.ResourceTest do
  # async: false — `new/0` reads `RELEASE_NAME`/`RELEASE_VSN`
  # OS env vars; tests mutate them.
  use ExUnit.Case, async: false

  setup do
    saved = %{
      "RELEASE_NAME" => System.get_env("RELEASE_NAME"),
      "RELEASE_VSN" => System.get_env("RELEASE_VSN")
    }

    Enum.each(saved, fn {k, _} -> System.delete_env(k) end)

    on_exit(fn ->
      Enum.each(saved, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end)

    :ok
  end

  describe "new/0 — no release env" do
    test "service.name falls back to \"unknown_service\"; service.version is nil" do
      attrs = Otel.Resource.new().attributes

      assert attrs["service.name"] == "unknown_service"
      # Key present, value nil — OTLP encoder maps to %AnyValue{}
      # (oneof unset) per `common/README.md` L50-L51.
      assert Map.has_key?(attrs, "service.version")
      assert is_nil(attrs["service.version"])
    end

    test "always emits SDK identity + deployment.environment" do
      attrs = Otel.Resource.new().attributes

      assert attrs["telemetry.sdk.name"] == "otel"
      assert attrs["telemetry.sdk.language"] == "elixir"
      assert is_binary(attrs["telemetry.sdk.version"]) and attrs["telemetry.sdk.version"] != ""
      assert attrs["deployment.environment"] in ["dev", "test", "prod"]
    end
  end

  describe "new/0 — RELEASE_NAME set" do
    test "service.name from RELEASE_NAME; service.version stays nil" do
      System.put_env("RELEASE_NAME", "my_app")

      attrs = Otel.Resource.new().attributes

      assert attrs["service.name"] == "my_app"
      assert is_nil(attrs["service.version"])
    end

    test "RELEASE_NAME and RELEASE_VSN both populate service.* attributes" do
      System.put_env("RELEASE_NAME", "my_app")
      System.put_env("RELEASE_VSN", "1.2.3")

      attrs = Otel.Resource.new().attributes

      assert attrs["service.name"] == "my_app"
      assert attrs["service.version"] == "1.2.3"
    end

    test "empty RELEASE_NAME stays as empty string (System.get_env default only on nil)" do
      System.put_env("RELEASE_NAME", "")

      attrs = Otel.Resource.new().attributes

      assert attrs["service.name"] == ""
    end
  end

  describe "new/0 — attribute key set" do
    test "always emits 6 keys" do
      keys =
        Otel.Resource.new().attributes
        |> Map.keys()
        |> Enum.sort()

      assert keys == [
               "deployment.environment",
               "service.name",
               "service.version",
               "telemetry.sdk.language",
               "telemetry.sdk.name",
               "telemetry.sdk.version"
             ]
    end
  end
end
