defmodule Otel.ResourceTest do
  # async: false — `default/0` reads OTEL_RESOURCE_ATTRIBUTES /
  # OTEL_SERVICE_NAME from the process-global environment.
  use ExUnit.Case, async: false

  describe "create/2" do
    test "accepts attributes as a map or keyword list; schema_url defaults to \"\"" do
      assert Otel.Resource.create(%{"key" => "value"}).attributes == %{"key" => "value"}
      assert Otel.Resource.create([{"key", "value"}]).attributes == %{"key" => "value"}
      assert Otel.Resource.create(%{}).schema_url == ""

      assert Otel.Resource.create(%{}, "https://example.com/schema").schema_url ==
               "https://example.com/schema"
    end
  end

  describe "merge/2" do
    test "updating attributes overwrite same keys; old keys without conflict survive" do
      old = Otel.Resource.create(%{"a" => "1", "b" => "old"})
      updating = Otel.Resource.create(%{"b" => "new", "c" => "3"})
      merged = Otel.Resource.merge(old, updating)

      assert merged.attributes == %{"a" => "1", "b" => "new", "c" => "3"}
    end

    # Spec resource/sdk.md L153-L160 — schema_url merge:
    # one empty + one set → use the set one;
    # both equal → keep that;
    # different non-empty → empty.
    test "schema_url merge: one-empty / matching / conflicting" do
      assert Otel.Resource.merge(
               Otel.Resource.create(%{}, ""),
               Otel.Resource.create(%{}, "https://new.com")
             ).schema_url == "https://new.com"

      assert Otel.Resource.merge(
               Otel.Resource.create(%{}, "https://old.com"),
               Otel.Resource.create(%{}, "")
             ).schema_url == "https://old.com"

      assert Otel.Resource.merge(
               Otel.Resource.create(%{}, "https://same.com"),
               Otel.Resource.create(%{}, "https://same.com")
             ).schema_url == "https://same.com"

      assert Otel.Resource.merge(
               Otel.Resource.create(%{}, "https://old.com"),
               Otel.Resource.create(%{}, "https://new.com")
             ).schema_url == ""
    end
  end

  describe "default/0" do
    test "SDK identity attributes + service.name=\"unknown_service\" fallback" do
      attrs = Otel.Resource.default().attributes

      assert attrs["telemetry.sdk.name"] == "otel"
      assert attrs["telemetry.sdk.language"] == "elixir"
      assert is_binary(attrs["telemetry.sdk.version"]) and attrs["telemetry.sdk.version"] != ""
      assert attrs["service.name"] == "unknown_service"

      assert Map.keys(attrs) |> Enum.sort() == [
               "service.name",
               "telemetry.sdk.language",
               "telemetry.sdk.name",
               "telemetry.sdk.version"
             ]
    end
  end
end
