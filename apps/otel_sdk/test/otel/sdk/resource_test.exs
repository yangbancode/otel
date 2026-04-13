defmodule Otel.SDK.ResourceTest do
  use ExUnit.Case

  setup do
    System.delete_env("OTEL_RESOURCE_ATTRIBUTES")
    System.delete_env("OTEL_SERVICE_NAME")

    on_exit(fn ->
      System.delete_env("OTEL_RESOURCE_ATTRIBUTES")
      System.delete_env("OTEL_SERVICE_NAME")
    end)

    :ok
  end

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
    test "includes SDK attributes" do
      resource = Otel.SDK.Resource.default()
      assert resource.attributes["telemetry.sdk.name"] == "otel"
      assert resource.attributes["telemetry.sdk.language"] == "elixir"
      assert is_binary(resource.attributes["telemetry.sdk.version"])
      assert resource.attributes["telemetry.sdk.version"] != ""
      assert resource.attributes["service.name"] == "unknown_service"
    end
  end

  describe "from_env/0" do
    test "parses OTEL_RESOURCE_ATTRIBUTES" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "key1=value1,key2=value2")
      resource = Otel.SDK.Resource.from_env()
      assert resource.attributes["key1"] == "value1"
      assert resource.attributes["key2"] == "value2"
    end

    test "handles percent-encoded values" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "key=hello%20world")
      resource = Otel.SDK.Resource.from_env()
      assert resource.attributes["key"] == "hello world"
    end

    test "OTEL_SERVICE_NAME overrides service.name" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "service.name=from_attrs")
      System.put_env("OTEL_SERVICE_NAME", "from_env")
      resource = Otel.SDK.Resource.from_env()
      assert resource.attributes["service.name"] == "from_env"
    end

    test "returns empty resource when no env vars set" do
      resource = Otel.SDK.Resource.from_env()
      assert resource.attributes == %{}
    end

    test "skips invalid pairs" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "valid=yes,=invalid,also=ok")
      resource = Otel.SDK.Resource.from_env()
      assert resource.attributes["valid"] == "yes"
      assert resource.attributes["also"] == "ok"
      assert map_size(resource.attributes) == 2
    end

    test "handles empty OTEL_RESOURCE_ATTRIBUTES" do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "")
      resource = Otel.SDK.Resource.from_env()
      assert resource.attributes == %{}
    end

    test "handles empty OTEL_SERVICE_NAME" do
      System.put_env("OTEL_SERVICE_NAME", "")
      resource = Otel.SDK.Resource.from_env()
      refute Map.has_key?(resource.attributes, "service.name")
    end
  end

  describe "integration with Configuration" do
    test "default config includes SDK resource with env override" do
      System.put_env("OTEL_SERVICE_NAME", "my-service")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.resource.attributes["service.name"] == "my-service"
      assert config.resource.attributes["telemetry.sdk.name"] == "otel"
    end
  end
end
