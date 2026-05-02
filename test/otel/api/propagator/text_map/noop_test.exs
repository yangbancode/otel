defmodule Otel.API.Propagator.TextMap.NoopTest do
  use ExUnit.Case, async: false

  # Spec context/api-propagators.md L322-L325 (MUST):
  # The OpenTelemetry API MUST use no-op propagators unless
  # explicitly configured otherwise.

  @ctx Otel.Ctx.new()

  # Setter / getter raise — proves Noop never invokes them.
  defp raising_setter, do: fn _k, _v, _c -> raise "setter MUST NOT be called" end
  defp raising_getter, do: fn _c, _k -> raise "getter MUST NOT be called" end

  describe "inject/3" do
    test "returns the carrier unchanged across carrier shapes" do
      assert Otel.API.Propagator.TextMap.Noop.inject(@ctx, [{"k", "v"}], raising_setter()) ==
               [{"k", "v"}]

      assert Otel.API.Propagator.TextMap.Noop.inject(@ctx, %{arbitrary: :map}, raising_setter()) ==
               %{arbitrary: :map}
    end
  end

  describe "extract/3" do
    test "returns the context unchanged across carrier shapes" do
      ctx = Otel.Ctx.set_value(@ctx, :my_key, :value)

      assert Otel.API.Propagator.TextMap.Noop.extract(ctx, [{"k", "v"}], raising_getter()) == ctx
      # Spec L100-L102 — MUST NOT throw on parse failure; Noop
      # satisfies this trivially by not parsing.
      assert Otel.API.Propagator.TextMap.Noop.extract(ctx, :garbage, raising_getter()) == ctx
      assert Otel.API.Propagator.TextMap.Noop.extract(ctx, nil, raising_getter()) == ctx
    end
  end

  test "fields/0 returns an empty list" do
    assert Otel.API.Propagator.TextMap.Noop.fields() == []
  end

  describe "installed as global default (spec L322-L325)" do
    setup do
      saved = :persistent_term.get({Otel.API.Propagator.TextMap, :global}, nil)
      :persistent_term.erase({Otel.API.Propagator.TextMap, :global})

      on_exit(fn ->
        if saved,
          do: :persistent_term.put({Otel.API.Propagator.TextMap, :global}, saved),
          else: :persistent_term.erase({Otel.API.Propagator.TextMap, :global})
      end)
    end

    test "get_propagator/0 returns Noop when none is set" do
      assert Otel.API.Propagator.TextMap.get_propagator() == Otel.API.Propagator.TextMap.Noop
    end

    test "facade inject/2 and extract/2 pass through unchanged" do
      carrier = [{"existing", "value"}]
      assert Otel.API.Propagator.TextMap.inject(@ctx, carrier) == carrier
      assert Otel.API.Propagator.TextMap.extract(@ctx, carrier) == @ctx
    end
  end
end
