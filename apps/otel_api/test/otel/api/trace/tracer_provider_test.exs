defmodule Otel.API.Trace.TracerProviderTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})
    :ok
  end

  describe "get_provider/0 and set_provider/1" do
    test "returns nil when no provider is set" do
      assert Otel.API.Trace.TracerProvider.get_provider() == nil
    end

    test "returns the set provider" do
      Otel.API.Trace.TracerProvider.set_provider(SomeProvider)
      assert Otel.API.Trace.TracerProvider.get_provider() == SomeProvider
    end
  end

  describe "get_tracer/1,2,3" do
    test "returns noop tracer when no SDK installed" do
      {module, _config} = Otel.API.Trace.TracerProvider.get_tracer("my_lib")
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "returns same tracer for same name" do
      tracer1 = Otel.API.Trace.TracerProvider.get_tracer("my_lib")
      tracer2 = Otel.API.Trace.TracerProvider.get_tracer("my_lib")
      assert tracer1 == tracer2
    end

    test "accepts version and schema_url" do
      tracer = Otel.API.Trace.TracerProvider.get_tracer("my_lib", "1.0.0", "https://example.com")
      assert {Otel.API.Trace.Tracer.Noop, []} == tracer
    end

    test "accepts attributes" do
      tracer =
        Otel.API.Trace.TracerProvider.get_tracer("my_lib", "1.0.0", nil, [
          Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("val"))
        ])

      assert {Otel.API.Trace.Tracer.Noop, []} == tracer
    end

    test "returns working tracer for nil name with warning" do
      {module, _config} = Otel.API.Trace.TracerProvider.get_tracer(nil)
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "returns working tracer for empty name with warning" do
      {module, _config} = Otel.API.Trace.TracerProvider.get_tracer("")
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "caches tracer in persistent_term" do
      tracer1 = Otel.API.Trace.TracerProvider.get_tracer("cached_lib")
      tracer2 = Otel.API.Trace.TracerProvider.get_tracer("cached_lib")
      assert tracer1 === tracer2
    end
  end

  describe "scope/1,2,3" do
    test "creates InstrumentationScope with name" do
      scope = Otel.API.Trace.TracerProvider.scope("my_lib")

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "",
               schema_url: nil,
               attributes: []
             } ==
               scope
    end

    test "creates InstrumentationScope with all fields" do
      scope =
        Otel.API.Trace.TracerProvider.scope("my_lib", "1.0.0", "https://example.com", [
          Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("val"))
        ])

      assert %Otel.API.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com",
               attributes: [
                 Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("val"))
               ]
             } == scope
    end
  end
end
