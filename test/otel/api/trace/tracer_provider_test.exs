defmodule Otel.API.Trace.TracerProviderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule FakeTracerProvider do
    @moduledoc false
    @behaviour Otel.API.Trace.TracerProvider

    @impl true
    def get_tracer(state, %Otel.API.InstrumentationScope{} = scope) do
      {__MODULE__, %{state: state, scope: scope}}
    end
  end

  setup do
    saved = :persistent_term.get({Otel.API.Trace.TracerProvider, :global}, nil)
    :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})

    on_exit(fn ->
      if saved,
        do: :persistent_term.put({Otel.API.Trace.TracerProvider, :global}, saved),
        else: :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})
    end)
  end

  describe "set_provider/1 + get_provider/0" do
    test "round-trip; nil before set, opaque tuple after" do
      assert Otel.API.Trace.TracerProvider.get_provider() == nil

      Otel.API.Trace.TracerProvider.set_provider({SomeProvider, :opaque_state})

      assert Otel.API.Trace.TracerProvider.get_provider() == {SomeProvider, :opaque_state}
    end
  end

  describe "get_tracer/1 — Noop fallback when no provider is set" do
    test "returns the Noop tracer handle for any scope (incl. empty name)" do
      assert {Otel.API.Trace.Tracer.Noop, []} ==
               Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{
                 name: "my_lib"
               })

      assert {Otel.API.Trace.Tracer.Noop, []} ==
               Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: ""})
    end

    # Spec trace/api.md L136-L140: two Tracers created with the
    # same parameters MUST be identical. Satisfied structurally.
    test "repeated calls with the same scope yield equal tracer handles" do
      scope = %Otel.API.InstrumentationScope{name: "my_lib"}

      assert Otel.API.Trace.TracerProvider.get_tracer(scope) ==
               Otel.API.Trace.TracerProvider.get_tracer(scope)
    end

    # Spec trace/api.md L125-L130 SHOULD-log lives in the SDK
    # provider; the API layer must NOT also log to avoid duplicate
    # warnings when both layers are loaded.
    test "empty scope name does not emit a warning at the API layer" do
      log =
        capture_log(fn ->
          Otel.API.Trace.TracerProvider.get_tracer(%Otel.API.InstrumentationScope{name: ""})
        end)

      refute log =~ "invalid Tracer name"
    end
  end

  describe "get_tracer/1 — dispatches to the registered provider" do
    setup do
      Otel.API.Trace.TracerProvider.set_provider({FakeTracerProvider, :installed})
    end

    test "forwards scope and provider state to the registered module" do
      scope = %Otel.API.InstrumentationScope{name: "installed_lib"}

      assert {FakeTracerProvider, %{state: :installed, scope: ^scope}} =
               Otel.API.Trace.TracerProvider.get_tracer(scope)
    end
  end

  # Regression: the resolve path was caching Noop in
  # `:persistent_term` before SDK install, and the cached Noop
  # survived `set_provider/1`, silently swallowing every later span.
  test "an SDK installed AFTER a Noop resolve takes effect on the next resolve" do
    scope = %Otel.API.InstrumentationScope{name: "bootstrap_race"}

    assert {Otel.API.Trace.Tracer.Noop, []} ==
             Otel.API.Trace.TracerProvider.get_tracer(scope)

    Otel.API.Trace.TracerProvider.set_provider({FakeTracerProvider, :installed})

    assert {FakeTracerProvider, %{state: :installed, scope: ^scope}} =
             Otel.API.Trace.TracerProvider.get_tracer(scope)
  end
end
