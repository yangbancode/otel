defmodule Otel.ResourceTest do
  # async: false — `build/0` reads `:otp_app` from `Application` env;
  # tests mutate it.
  use ExUnit.Case, async: false

  setup do
    prev = Application.get_env(:otel, :otp_app)
    Application.delete_env(:otel, :otp_app)

    on_exit(fn ->
      case prev do
        nil -> Application.delete_env(:otel, :otp_app)
        app -> Application.put_env(:otel, :otp_app, app)
      end
    end)

    :ok
  end

  describe "build/0 — no :otp_app" do
    test "service.name falls back to \"unknown_service\"; service.version key is absent" do
      attrs = Otel.Resource.build().attributes

      assert attrs["service.name"] == "unknown_service"
      refute Map.has_key?(attrs, "service.version")
    end

    test "always emits SDK identity + deployment.environment" do
      attrs = Otel.Resource.build().attributes

      assert attrs["telemetry.sdk.name"] == "otel"
      assert attrs["telemetry.sdk.language"] == "elixir"
      assert is_binary(attrs["telemetry.sdk.version"]) and attrs["telemetry.sdk.version"] != ""
      assert attrs["deployment.environment"] in ["dev", "test", "prod"]
    end
  end

  describe "build/0 — with :otp_app" do
    test "service.name + service.version come from the configured otp_app" do
      Application.put_env(:otel, :otp_app, :otel)

      attrs = Otel.Resource.build().attributes

      assert attrs["service.name"] == "otel"
      assert attrs["service.version"] == to_string(Application.spec(:otel, :vsn))
    end

    test "unknown otp_app: service.name takes the atom; service.version key is absent" do
      Application.put_env(:otel, :otp_app, :nonexistent_app_xyz)

      attrs = Otel.Resource.build().attributes

      assert attrs["service.name"] == "nonexistent_app_xyz"
      refute Map.has_key?(attrs, "service.version")
    end
  end

  describe "build/0 — attribute key set" do
    test "5 keys without :otp_app (no service.version)" do
      keys =
        Otel.Resource.build().attributes
        |> Map.keys()
        |> Enum.sort()

      assert keys == [
               "deployment.environment",
               "service.name",
               "telemetry.sdk.language",
               "telemetry.sdk.name",
               "telemetry.sdk.version"
             ]
    end

    test "6 keys with a loaded :otp_app (service.version included)" do
      Application.put_env(:otel, :otp_app, :otel)

      keys =
        Otel.Resource.build().attributes
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
