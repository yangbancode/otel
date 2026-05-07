defmodule Otel.ResourceTest do
  # async: false — `new/0` reads `Application.get_env(:otel, :otp_app)`
  # and `Application.spec/2`; tests mutate the former and rely on
  # the latter's global state.
  use ExUnit.Case, async: false

  setup do
    prev_app = Application.get_env(:otel, :otp_app)
    Application.delete_env(:otel, :otp_app)

    on_exit(fn ->
      case prev_app do
        nil -> Application.delete_env(:otel, :otp_app)
        v -> Application.put_env(:otel, :otp_app, v)
      end
    end)

    :ok
  end

  describe "new/0 — no :otp_app config" do
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

  describe "new/0 — :otp_app config set to a loaded application" do
    test "service.name from :otp_app atom; service.version from Application.spec/2" do
      # `:otel` is loaded throughout the test suite — its vsn is
      # whatever `mix.exs` declares, which is exactly the contract
      # we want to verify (single source of truth).
      Application.put_env(:otel, :otp_app, :otel)

      attrs = Otel.Resource.new().attributes

      assert attrs["service.name"] == "otel"

      expected_vsn = :otel |> Application.spec(:vsn) |> List.to_string()
      assert attrs["service.version"] == expected_vsn
      assert attrs["service.version"] =~ ~r/^\d+\.\d+\.\d+/
    end
  end

  describe "new/0 — :otp_app config set to an unloaded application" do
    test "service.name from atom; service.version is nil (Application.spec returns nil)" do
      # An atom that doesn't correspond to a loaded OTP application
      # — `Application.spec/2` returns `nil`, so service.version
      # falls back to the same nil-AnyValue treatment as the
      # no-:otp_app case.
      Application.put_env(:otel, :otp_app, :no_such_application)

      attrs = Otel.Resource.new().attributes

      assert attrs["service.name"] == "no_such_application"
      assert is_nil(attrs["service.version"])
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
