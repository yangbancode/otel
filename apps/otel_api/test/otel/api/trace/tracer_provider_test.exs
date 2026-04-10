defmodule Otel.API.Trace.TracerProviderTest do
  use ExUnit.Case

  alias Otel.API.Trace.{InstrumentationScope, Noop, TracerProvider}

  setup do
    # Clean up persistent_term keys between tests
    :persistent_term.get()
    |> Enum.filter(fn {key, _} ->
      match?({Otel.API.Trace.TracerProvider, _}, key)
    end)
    |> Enum.each(fn {key, _} -> :persistent_term.erase(key) end)

    :ok
  end

  describe "get_provider/0 and set_provider/1" do
    test "returns nil when no provider is set" do
      assert TracerProvider.get_provider() == nil
    end

    test "returns the set provider" do
      TracerProvider.set_provider(SomeProvider)
      assert TracerProvider.get_provider() == SomeProvider
    end
  end

  describe "get_tracer/1,2,3" do
    test "returns noop tracer when no SDK installed" do
      {module, _config} = TracerProvider.get_tracer("my_lib")
      assert module == Noop
    end

    test "returns same tracer for same name" do
      tracer1 = TracerProvider.get_tracer("my_lib")
      tracer2 = TracerProvider.get_tracer("my_lib")
      assert tracer1 == tracer2
    end

    test "accepts version and schema_url" do
      tracer = TracerProvider.get_tracer("my_lib", "1.0.0", "https://example.com")
      assert {Noop, []} == tracer
    end

    test "returns working tracer for nil name with warning" do
      {module, _config} = TracerProvider.get_tracer(nil)
      assert module == Noop
    end

    test "returns working tracer for empty name with warning" do
      {module, _config} = TracerProvider.get_tracer("")
      assert module == Noop
    end

    test "caches tracer in persistent_term" do
      tracer1 = TracerProvider.get_tracer("cached_lib")
      tracer2 = TracerProvider.get_tracer("cached_lib")
      assert tracer1 === tracer2
    end
  end

  describe "scope/1,2,3" do
    test "creates InstrumentationScope with name" do
      scope = TracerProvider.scope("my_lib")
      assert %InstrumentationScope{name: "my_lib", version: "", schema_url: nil} == scope
    end

    test "creates InstrumentationScope with all fields" do
      scope = TracerProvider.scope("my_lib", "1.0.0", "https://example.com")

      assert %InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } == scope
    end
  end
end
