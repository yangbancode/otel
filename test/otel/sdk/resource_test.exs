defmodule Otel.SDK.ResourceTest do
  # async: false because `default/0` reads OTEL_RESOURCE_ATTRIBUTES
  # and OTEL_SERVICE_NAME from the process-global environment;
  # parallel tests would race on `System.put_env/delete_env`.
  use ExUnit.Case, async: false

  describe "create/2" do
    test "creates from map" do
      resource = Otel.SDK.Resource.create(%{"key" => "value"})
      assert resource.attributes["key"] == "value"
      assert resource.schema_url == ""
    end

    test "creates from keyword list" do
      resource = Otel.SDK.Resource.create([{"key", "value"}])
      assert resource.attributes["key"] == "value"
    end

    test "creates with schema_url" do
      resource = Otel.SDK.Resource.create(%{}, "https://example.com/schema")
      assert resource.schema_url == "https://example.com/schema"
    end
  end

  describe "merge/2" do
    test "merges attributes, updating takes precedence" do
      old = Otel.SDK.Resource.create(%{"a" => "1", "b" => "old"})
      updating = Otel.SDK.Resource.create(%{"b" => "new", "c" => "3"})
      merged = Otel.SDK.Resource.merge(old, updating)

      assert merged.attributes["a"] == "1"
      assert merged.attributes["b"] == "new"
      assert merged.attributes["c"] == "3"
    end

    test "empty old schema_url uses updating's" do
      old = Otel.SDK.Resource.create(%{}, "")
      updating = Otel.SDK.Resource.create(%{}, "https://new.com")
      assert Otel.SDK.Resource.merge(old, updating).schema_url == "https://new.com"
    end

    test "empty updating schema_url uses old's" do
      old = Otel.SDK.Resource.create(%{}, "https://old.com")
      updating = Otel.SDK.Resource.create(%{}, "")
      assert Otel.SDK.Resource.merge(old, updating).schema_url == "https://old.com"
    end

    test "matching schema_urls preserved" do
      old = Otel.SDK.Resource.create(%{}, "https://same.com")
      updating = Otel.SDK.Resource.create(%{}, "https://same.com")
      assert Otel.SDK.Resource.merge(old, updating).schema_url == "https://same.com"
    end

    test "conflicting schema_urls result in empty" do
      old = Otel.SDK.Resource.create(%{}, "https://old.com")
      updating = Otel.SDK.Resource.create(%{}, "https://new.com")
      assert Otel.SDK.Resource.merge(old, updating).schema_url == ""
    end
  end

  describe "default/0" do
    setup do
      original_otel_resource_attrs = System.get_env("OTEL_RESOURCE_ATTRIBUTES")
      original_otel_service_name = System.get_env("OTEL_SERVICE_NAME")

      System.delete_env("OTEL_RESOURCE_ATTRIBUTES")
      System.delete_env("OTEL_SERVICE_NAME")

      on_exit(fn ->
        restore_env("OTEL_RESOURCE_ATTRIBUTES", original_otel_resource_attrs)
        restore_env("OTEL_SERVICE_NAME", original_otel_service_name)
      end)

      :ok
    end

    test "includes SDK attributes (no env vars)" do
      resource = Otel.SDK.Resource.default()
      assert resource.attributes["telemetry.sdk.name"] == "otel"
      assert resource.attributes["telemetry.sdk.language"] == "elixir"
      assert is_binary(resource.attributes["telemetry.sdk.version"])
      assert resource.attributes["telemetry.sdk.version"] != ""
      assert resource.attributes["service.name"] == "unknown_service"
    end

    test "OTEL_SERVICE_NAME populates service.name (spec L116)" do
      System.put_env("OTEL_SERVICE_NAME", "my_service")
      resource = Otel.SDK.Resource.default()
      assert resource.attributes["service.name"] == "my_service"
    end

    test "OTEL_RESOURCE_ATTRIBUTES populates attributes (spec L179-L182)" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "k1=v1,k2=v2,host.name=worker-7")
      resource = Otel.SDK.Resource.default()

      assert resource.attributes["k1"] == "v1"
      assert resource.attributes["k2"] == "v2"
      assert resource.attributes["host.name"] == "worker-7"
    end

    test "OTEL_RESOURCE_ATTRIBUTES service.name used when OTEL_SERVICE_NAME unset" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "service.name=from_attrs")
      resource = Otel.SDK.Resource.default()
      assert resource.attributes["service.name"] == "from_attrs"
    end

    test "OTEL_SERVICE_NAME takes precedence over OTEL_RESOURCE_ATTRIBUTES service.name (spec L116)" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "service.name=from_attrs")
      System.put_env("OTEL_SERVICE_NAME", "from_env")

      resource = Otel.SDK.Resource.default()
      assert resource.attributes["service.name"] == "from_env"
    end

    test "percent-encoded `,` and `=` are decoded (spec L186-L187)" do
      # comma in value: `%2C`. Equals in value: `%3D`.
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "csv=a%2Cb%2Cc,kv=k%3Dv")
      resource = Otel.SDK.Resource.default()

      assert resource.attributes["csv"] == "a,b,c"
      assert resource.attributes["kv"] == "k=v"
    end

    test "percent-encoded UTF-8 values decode correctly (spec L188-L189)" do
      # `한글` UTF-8 bytes percent-encoded
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "label=%ED%95%9C%EA%B8%80")
      resource = Otel.SDK.Resource.default()
      assert resource.attributes["label"] == "한글"
    end

    test "malformed pair discards entire OTEL_RESOURCE_ATTRIBUTES (spec L191-L193)" do
      # second pair lacks `=` — whole value discarded
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "good=ok,malformed,also=fine")
      resource = Otel.SDK.Resource.default()

      refute Map.has_key?(resource.attributes, "good")
      refute Map.has_key?(resource.attributes, "also")
    end

    test "empty OTEL_RESOURCE_ATTRIBUTES treated as unset" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "")
      resource = Otel.SDK.Resource.default()

      assert resource.attributes["service.name"] == "unknown_service"

      assert Map.keys(resource.attributes) |> Enum.sort() ==
               [
                 "service.name",
                 "telemetry.sdk.language",
                 "telemetry.sdk.name",
                 "telemetry.sdk.version"
               ]
    end

    test "empty OTEL_SERVICE_NAME treated as unset" do
      System.put_env("OTEL_SERVICE_NAME", "")
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "service.name=from_attrs")
      resource = Otel.SDK.Resource.default()
      assert resource.attributes["service.name"] == "from_attrs"
    end
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
