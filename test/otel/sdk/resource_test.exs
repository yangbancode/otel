defmodule Otel.SDK.ResourceTest do
  # async: false — `default/0` reads OTEL_RESOURCE_ATTRIBUTES /
  # OTEL_SERVICE_NAME from the process-global environment.
  use ExUnit.Case, async: false

  describe "create/2" do
    test "accepts attributes as a map or keyword list; schema_url defaults to \"\"" do
      assert Otel.SDK.Resource.create(%{"key" => "value"}).attributes == %{"key" => "value"}
      assert Otel.SDK.Resource.create([{"key", "value"}]).attributes == %{"key" => "value"}
      assert Otel.SDK.Resource.create(%{}).schema_url == ""

      assert Otel.SDK.Resource.create(%{}, "https://example.com/schema").schema_url ==
               "https://example.com/schema"
    end
  end

  describe "merge/2" do
    test "updating attributes overwrite same keys; old keys without conflict survive" do
      old = Otel.SDK.Resource.create(%{"a" => "1", "b" => "old"})
      updating = Otel.SDK.Resource.create(%{"b" => "new", "c" => "3"})
      merged = Otel.SDK.Resource.merge(old, updating)

      assert merged.attributes == %{"a" => "1", "b" => "new", "c" => "3"}
    end

    # Spec resource/sdk.md L153-L160 — schema_url merge:
    # one empty + one set → use the set one;
    # both equal → keep that;
    # different non-empty → empty.
    test "schema_url merge: one-empty / matching / conflicting" do
      assert Otel.SDK.Resource.merge(
               Otel.SDK.Resource.create(%{}, ""),
               Otel.SDK.Resource.create(%{}, "https://new.com")
             ).schema_url == "https://new.com"

      assert Otel.SDK.Resource.merge(
               Otel.SDK.Resource.create(%{}, "https://old.com"),
               Otel.SDK.Resource.create(%{}, "")
             ).schema_url == "https://old.com"

      assert Otel.SDK.Resource.merge(
               Otel.SDK.Resource.create(%{}, "https://same.com"),
               Otel.SDK.Resource.create(%{}, "https://same.com")
             ).schema_url == "https://same.com"

      assert Otel.SDK.Resource.merge(
               Otel.SDK.Resource.create(%{}, "https://old.com"),
               Otel.SDK.Resource.create(%{}, "https://new.com")
             ).schema_url == ""
    end
  end

  describe "default/0" do
    setup do
      saved_attrs = System.get_env("OTEL_RESOURCE_ATTRIBUTES")
      saved_service = System.get_env("OTEL_SERVICE_NAME")

      System.delete_env("OTEL_RESOURCE_ATTRIBUTES")
      System.delete_env("OTEL_SERVICE_NAME")

      on_exit(fn ->
        restore_env("OTEL_RESOURCE_ATTRIBUTES", saved_attrs)
        restore_env("OTEL_SERVICE_NAME", saved_service)
      end)
    end

    test "no env vars → SDK identity attributes + service.name=\"unknown_service\"" do
      attrs = Otel.SDK.Resource.default().attributes

      assert attrs["telemetry.sdk.name"] == "otel"
      assert attrs["telemetry.sdk.language"] == "elixir"
      assert is_binary(attrs["telemetry.sdk.version"]) and attrs["telemetry.sdk.version"] != ""
      assert attrs["service.name"] == "unknown_service"
    end

    # Spec sdk-environment-variables.md L116 — OTEL_SERVICE_NAME
    # always wins over the OTEL_RESOURCE_ATTRIBUTES service.name entry.
    test "OTEL_SERVICE_NAME wins over OTEL_RESOURCE_ATTRIBUTES service.name" do
      System.put_env("OTEL_SERVICE_NAME", "from_env")
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "service.name=from_attrs,k1=v1")

      attrs = Otel.SDK.Resource.default().attributes
      assert attrs["service.name"] == "from_env"
      assert attrs["k1"] == "v1"
    end

    test "without OTEL_SERVICE_NAME, OTEL_RESOURCE_ATTRIBUTES service.name applies" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "service.name=from_attrs")
      assert Otel.SDK.Resource.default().attributes["service.name"] == "from_attrs"
    end

    # Spec L186-L189 — values are RFC 3986 percent-decoded; commas
    # and equals inside values are %2C and %3D.
    test "percent-decodes commas, equals, and UTF-8 bytes in values" do
      System.put_env(
        "OTEL_RESOURCE_ATTRIBUTES",
        "csv=a%2Cb%2Cc,kv=k%3Dv,label=%ED%95%9C%EA%B8%80"
      )

      attrs = Otel.SDK.Resource.default().attributes
      assert attrs["csv"] == "a,b,c"
      assert attrs["kv"] == "k=v"
      assert attrs["label"] == "한글"
    end

    # Spec L191-L193: a malformed pair (missing `=`) discards the
    # ENTIRE value, not just the bad pair.
    test "malformed pair discards the whole OTEL_RESOURCE_ATTRIBUTES" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "good=ok,malformed,also=fine")
      attrs = Otel.SDK.Resource.default().attributes

      refute Map.has_key?(attrs, "good")
      refute Map.has_key?(attrs, "also")
    end

    test "empty env-var values are treated as unset" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "")
      attrs = Otel.SDK.Resource.default().attributes
      assert attrs["service.name"] == "unknown_service"

      assert Map.keys(attrs) |> Enum.sort() == [
               "service.name",
               "telemetry.sdk.language",
               "telemetry.sdk.name",
               "telemetry.sdk.version"
             ]

      System.put_env("OTEL_SERVICE_NAME", "")
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "service.name=from_attrs")
      assert Otel.SDK.Resource.default().attributes["service.name"] == "from_attrs"
    end
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
