defmodule Otel.API.Trace.TracerProviderTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  setup do
    :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})
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

    test "delegates to the registered provider" do
      Otel.API.Trace.TracerProvider.set_provider({FakeTracerProvider, :installed})

      scope = %Otel.API.InstrumentationScope{name: "installed_lib"}

      {module, %{state: :installed, scope: ^scope}} =
        Otel.API.Trace.TracerProvider.get_tracer(scope)

      assert module == FakeTracerProvider
    end

    # Regression test for the bootstrap race where a pre-SDK
    # `get_tracer/1` would cache Noop in `:persistent_term`, and
    # that cached Noop would survive SDK installation — silently
    # dropping every subsequent span even though a real provider
    # was registered.
    test "later-installed provider takes effect immediately (no stale Noop)" do
      scope = %Otel.API.InstrumentationScope{name: "bootstrap_race"}

      # Step 1: Resolve BEFORE any provider — should be Noop.
      assert {Otel.API.Trace.Tracer.Noop, []} ==
               Otel.API.Trace.TracerProvider.get_tracer(scope)

      # Step 2: Install provider AFTER the first resolve.
      Otel.API.Trace.TracerProvider.set_provider({FakeTracerProvider, :installed})

      # Step 3: Second resolve MUST hit the new provider, not a
      # stale Noop from step 1's resolution.
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

    # Spec `trace/api.md` L136-L140: "two Tracers created with the
    # same parameters MUST be identical". Satisfied via structural
    # equality (not reference identity) since the Noop case always
    # returns `{Noop, []}`.
    test "returns structurally equal tracers for repeated equal scopes" do
      tracer1 =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: "my_lib"})

      tracer2 =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: "my_lib"})

      assert tracer1 == tracer2
    end

    test "different scopes resolve independently when no SDK installed" do
      scope_a = %Otel.API.InstrumentationScope{name: "my_lib", version: "1.0.0"}
      scope_b = %Otel.API.InstrumentationScope{name: "my_lib", version: "2.0.0"}

      assert {Otel.API.Trace.Tracer.Noop, []} ==
               Otel.API.Trace.TracerProvider.get_tracer(scope_a)

      assert {Otel.API.Trace.Tracer.Noop, []} ==
               Otel.API.Trace.TracerProvider.get_tracer(scope_b)
    end

    test "returns a working Tracer for empty Tracer name (spec L125-L130)" do
      tracer =
        Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: ""})

      assert {Otel.API.Trace.Tracer.Noop, []} == tracer
    end

    test "no warning at API layer for empty Tracer name (consolidated to SDK)" do
      # The spec L125-L130 SHOULD-log is enforced once at the SDK
      # provider; the API layer only handles the Noop fallback to
      # avoid double-warning when both API and SDK are loaded.
      log =
        capture_log(fn ->
          Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: ""})
        end)

      refute log =~ "invalid Tracer name"
    end
  end
end
