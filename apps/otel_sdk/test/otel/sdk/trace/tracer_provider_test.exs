defmodule Otel.SDK.Trace.TracerProviderTest.OkProcessor do
  def shutdown(_config), do: :ok
  def force_flush(_config), do: :ok
end

defmodule Otel.SDK.Trace.TracerProviderTest.FailProcessor do
  def shutdown(_config), do: {:error, :shutdown_failed}
  def force_flush(_config), do: {:error, :flush_failed}
end

defmodule Otel.SDK.Trace.TracerProviderTest.CrashProcessor do
  def shutdown(_config), do: raise("boom")
  def force_flush(_config), do: throw(:crash)
end

defmodule Otel.SDK.Trace.TracerProviderTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = Otel.SDK.Trace.TracerProvider.start_link(config: %{})
    %{provider: pid}
  end

  describe "start_link/1" do
    test "starts with default config" do
      {:ok, pid} = Otel.SDK.Trace.TracerProvider.start_link()
      assert Process.alive?(pid)
    end

    test "registers as global provider on start" do
      {:ok, _pid} = Otel.SDK.Trace.TracerProvider.start_link()
      assert Otel.API.Trace.TracerProvider.get_provider() == Otel.SDK.Trace.TracerProvider
    end

    test "starts with custom config" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(config: %{resource: %{service: "test"}})

      assert Otel.SDK.Trace.TracerProvider.resource(pid) == %{service: "test"}
    end
  end

  describe "get_tracer/2,3,4" do
    test "returns SDK tracer tuple", %{provider: pid} do
      {module, tracer_config} = Otel.SDK.Trace.TracerProvider.get_tracer(pid, "my_lib")
      assert module == Otel.SDK.Trace.Tracer
      assert %{sampler: _, id_generator: _, span_limits: _, scope: _} = tracer_config
    end

    test "tracer includes instrumentation scope", %{provider: pid} do
      {_module, %{scope: scope}} =
        Otel.SDK.Trace.TracerProvider.get_tracer(pid, "my_lib", "1.0.0", "https://example.com")

      assert %Otel.API.Trace.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = scope
    end

    test "tracer includes initialized sampler", %{provider: pid} do
      {_module, %{sampler: sampler}} = Otel.SDK.Trace.TracerProvider.get_tracer(pid, "my_lib")
      # sampler is already initialized {module, description, config} tuple
      assert {Otel.SDK.Trace.Sampler.ParentBased, _desc, _config} = sampler
    end

    test "tracer includes id_generator and span_limits", %{provider: pid} do
      {_module, config} = Otel.SDK.Trace.TracerProvider.get_tracer(pid, "my_lib")
      assert config.id_generator == Otel.SDK.Trace.IdGenerator.Default
      assert %Otel.SDK.Trace.SpanLimits{} = config.span_limits
    end
  end

  describe "config/1" do
    test "returns merged config with defaults", %{provider: pid} do
      config = Otel.SDK.Trace.TracerProvider.config(pid)

      assert config.sampler ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}

      assert config.processors == []
      assert config.id_generator == Otel.SDK.Trace.IdGenerator.Default
      assert config.span_limits.attribute_count_limit == 128
    end

    test "custom config overrides defaults" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            sampler: {Otel.SDK.Trace.Sampler.AlwaysOff, []},
            resource: %{service: "custom"}
          }
        )

      config = Otel.SDK.Trace.TracerProvider.config(pid)
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOff, []}
      assert config.resource == %{service: "custom"}
      # defaults preserved for unset keys
      assert config.processors == []
    end
  end

  describe "resource/1" do
    test "returns empty resource by default", %{provider: pid} do
      assert Otel.SDK.Trace.TracerProvider.resource(pid) == %{}
    end
  end

  describe "shutdown/1" do
    test "returns :ok with no processors", %{provider: pid} do
      assert Otel.SDK.Trace.TracerProvider.shutdown(pid) == :ok
    end

    test "invokes shutdown on all processors" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}},
              {Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}}
            ]
          }
        )

      assert Otel.SDK.Trace.TracerProvider.shutdown(pid) == :ok
    end

    test "collects errors from failing processors" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}},
              {Otel.SDK.Trace.TracerProviderTest.FailProcessor, %{}}
            ]
          }
        )

      assert {:error, [{Otel.SDK.Trace.TracerProviderTest.FailProcessor, :shutdown_failed}]} =
               Otel.SDK.Trace.TracerProvider.shutdown(pid)
    end

    test "catches crashed processors" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [{Otel.SDK.Trace.TracerProviderTest.CrashProcessor, %{}}]
          }
        )

      assert {:error, [{Otel.SDK.Trace.TracerProviderTest.CrashProcessor, {:error, _}}]} =
               Otel.SDK.Trace.TracerProvider.shutdown(pid)
    end

    test "returns noop tracer after shutdown", %{provider: pid} do
      Otel.SDK.Trace.TracerProvider.shutdown(pid)
      {module, _} = Otel.SDK.Trace.TracerProvider.get_tracer(pid, "my_lib")
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "second shutdown returns error", %{provider: pid} do
      assert Otel.SDK.Trace.TracerProvider.shutdown(pid) == :ok
      assert Otel.SDK.Trace.TracerProvider.shutdown(pid) == {:error, :already_shut_down}
    end
  end

  describe "force_flush/1" do
    test "returns :ok with no processors", %{provider: pid} do
      assert Otel.SDK.Trace.TracerProvider.force_flush(pid) == :ok
    end

    test "invokes force_flush on all processors" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [{Otel.SDK.Trace.TracerProviderTest.OkProcessor, %{}}]
          }
        )

      assert Otel.SDK.Trace.TracerProvider.force_flush(pid) == :ok
    end

    test "collects errors from failing processors" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [{Otel.SDK.Trace.TracerProviderTest.FailProcessor, %{}}]
          }
        )

      assert {:error, [{Otel.SDK.Trace.TracerProviderTest.FailProcessor, :flush_failed}]} =
               Otel.SDK.Trace.TracerProvider.force_flush(pid)
    end

    test "catches crashed processors" do
      {:ok, pid} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [{Otel.SDK.Trace.TracerProviderTest.CrashProcessor, %{}}]
          }
        )

      assert {:error, [{Otel.SDK.Trace.TracerProviderTest.CrashProcessor, {:throw, :crash}}]} =
               Otel.SDK.Trace.TracerProvider.force_flush(pid)
    end

    test "returns error after shutdown", %{provider: pid} do
      Otel.SDK.Trace.TracerProvider.shutdown(pid)
      assert Otel.SDK.Trace.TracerProvider.force_flush(pid) == {:error, :shut_down}
    end
  end
end
