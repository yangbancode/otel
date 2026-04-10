defmodule Otel.SDK.Trace.TracerProviderTest do
  use ExUnit.Case

  alias Otel.API.Trace.InstrumentationScope
  alias Otel.SDK.Trace.{Tracer, TracerProvider}

  setup do
    {:ok, pid} = TracerProvider.start_link(config: %{})
    %{provider: pid}
  end

  describe "start_link/1" do
    test "starts with default config" do
      {:ok, pid} = TracerProvider.start_link()
      assert Process.alive?(pid)
    end

    test "registers as global provider on start" do
      {:ok, _pid} = TracerProvider.start_link()
      assert Otel.API.Trace.TracerProvider.get_provider() == TracerProvider
    end

    test "starts with custom config" do
      {:ok, pid} = TracerProvider.start_link(config: %{resource: %{service: "test"}})
      assert TracerProvider.resource(pid) == %{service: "test"}
    end
  end

  describe "get_tracer/2,3,4" do
    test "returns SDK tracer tuple", %{provider: pid} do
      {module, tracer_config} = TracerProvider.get_tracer(pid, "my_lib")
      assert module == Tracer
      assert %{provider: ^pid, scope: _} = tracer_config
    end

    test "tracer includes instrumentation scope", %{provider: pid} do
      {_module, %{scope: scope}} =
        TracerProvider.get_tracer(pid, "my_lib", "1.0.0", "https://example.com")

      assert %InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = scope
    end

    test "tracer holds provider reference, not config copy", %{provider: pid} do
      {_module, %{provider: provider}} = TracerProvider.get_tracer(pid, "my_lib")
      assert provider == pid
      # config is accessed via provider, not copied
      assert TracerProvider.config(provider).sampler == {Otel.SDK.Trace.Sampler.AlwaysOn, []}
    end
  end

  describe "config/1" do
    test "returns merged config with defaults", %{provider: pid} do
      config = TracerProvider.config(pid)
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOn, []}
      assert config.processors == []
      assert config.id_generator == Otel.SDK.Trace.IdGenerator.Default
      assert config.span_limits.attribute_count_limit == 128
    end

    test "custom config overrides defaults" do
      {:ok, pid} =
        TracerProvider.start_link(
          config: %{
            sampler: {Otel.SDK.Trace.Sampler.AlwaysOff, []},
            resource: %{service: "custom"}
          }
        )

      config = TracerProvider.config(pid)
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOff, []}
      assert config.resource == %{service: "custom"}
      # defaults preserved for unset keys
      assert config.processors == []
    end
  end

  describe "resource/1" do
    test "returns empty resource by default", %{provider: pid} do
      assert TracerProvider.resource(pid) == %{}
    end
  end
end
