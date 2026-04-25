defmodule Otel.SDK.ResourceTest do
  use ExUnit.Case, async: true

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
end
