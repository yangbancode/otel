defmodule Otel.API.Trace.TracerProviderTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})

    for {key, _} <- :persistent_term.get(),
        is_tuple(key) and tuple_size(key) == 2 and
          elem(key, 0) == {Otel.API.Trace.TracerProvider, :tracer} do
      :persistent_term.erase(key)
    end

    :ok
  end

  describe "get_provider/0 and set_provider/1" do
    test "returns nil when no provider is set" do
      assert Otel.API.Trace.TracerProvider.get_provider() == nil
    end

    test "returns the set provider" do
      Otel.API.Trace.TracerProvider.set_provider({SomeProvider, :opaque_state})
      assert Otel.API.Trace.TracerProvider.get_provider() == {SomeProvider, :opaque_state}
    end
  end

  describe "get_tracer/1 dispatch via registered provider" do
    defmodule FakeTracerProvider do
      @moduledoc false
      @behaviour Otel.API.Trace.TracerProvider

      @impl true
      def get_tracer(state, %Otel.API.InstrumentationScope{} = scope) do
        {__MODULE__, %{state: state, scope: scope}}
      end
    end

    test "delegates to registered provider and caches result" do
      Otel.API.Trace.TracerProvider.set_provider({FakeTracerProvider, :installed})

      scope = %Otel.API.InstrumentationScope{name: "installed_lib"}

      {module, %{state: :installed, scope: ^scope}} =
        Otel.API.Trace.TracerProvider.get_tracer(scope)

      assert module == FakeTracerProvider
    end
  end

  describe "get_tracer/1" do
    test "returns noop tracer when no SDK installed" do
      {module, _config} =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "returns same tracer for equal scopes" do
      tracer1 =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: "my_lib"})

      tracer2 =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert tracer1 == tracer2
    end

    test "scopes differing in version produce separate cache entries" do
      scope_a = %Otel.API.InstrumentationScope{name: "my_lib", version: "1.0.0"}
      scope_b = %Otel.API.InstrumentationScope{name: "my_lib", version: "2.0.0"}

      assert {Otel.API.Trace.Tracer.Noop, []} ==
               Otel.API.Trace.TracerProvider.get_tracer(scope_a)

      assert {Otel.API.Trace.Tracer.Noop, []} ==
               Otel.API.Trace.TracerProvider.get_tracer(scope_b)
    end

    test "caches tracer in persistent_term" do
      tracer1 =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{
          name: "cached_lib"
        })

      tracer2 =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{
          name: "cached_lib"
        })

      assert tracer1 === tracer2
    end
  end
end
