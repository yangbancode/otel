defmodule Otel.API.Propagator.TextMap.NoopTest do
  use ExUnit.Case, async: true

  describe "inject/3" do
    test "returns carrier unchanged" do
      carrier = [{"traceparent", "value"}, {"other", "thing"}]
      ctx = Otel.API.Ctx.new()

      setter = fn _k, _v, _c -> raise "setter MUST NOT be called" end

      assert Otel.API.Propagator.TextMap.Noop.inject(ctx, carrier, setter) == carrier
    end

    test "accepts any carrier type without touching it" do
      carrier = %{arbitrary: :map}
      ctx = Otel.API.Ctx.new()
      setter = fn _k, _v, c -> c end

      assert Otel.API.Propagator.TextMap.Noop.inject(ctx, carrier, setter) == carrier
    end
  end

  describe "extract/3" do
    test "returns context unchanged" do
      ctx = Otel.API.Ctx.new() |> Otel.API.Ctx.set_value(:my_key, :value)
      carrier = [{"traceparent", "00-abc-def-01"}]

      getter = fn _c, _k -> raise "getter MUST NOT be called" end

      assert Otel.API.Propagator.TextMap.Noop.extract(ctx, carrier, getter) == ctx
    end

    test "does not throw on malformed carrier (spec L100-L102)" do
      # Spec MUST NOT throw on parse failure — Noop satisfies this
      # trivially by not parsing anything.
      ctx = Otel.API.Ctx.new()
      getter = fn _c, _k -> raise "getter MUST NOT be called" end

      assert Otel.API.Propagator.TextMap.Noop.extract(ctx, :garbage, getter) == ctx
      assert Otel.API.Propagator.TextMap.Noop.extract(ctx, nil, getter) == ctx
    end
  end

  describe "fields/0" do
    test "returns an empty list" do
      assert Otel.API.Propagator.TextMap.Noop.fields() == []
    end
  end

  describe "behaviour conformance" do
    test "implements Otel.API.Propagator.TextMap behaviour" do
      behaviours = Otel.API.Propagator.TextMap.Noop.module_info(:attributes)[:behaviour] || []
      assert Otel.API.Propagator.TextMap in behaviours
    end
  end

  describe "installed as global default" do
    setup do
      :persistent_term.erase({Otel.API.Propagator.TextMap, :global})
      :ok
    end

    test "get_propagator/0 returns Noop when none is set (spec L322-L325)" do
      assert Otel.API.Propagator.TextMap.get_propagator() == Otel.API.Propagator.TextMap.Noop
    end

    test "facade inject/3 is a no-op when no propagator is configured" do
      carrier = [{"existing", "value"}]
      ctx = Otel.API.Ctx.new()

      assert Otel.API.Propagator.TextMap.inject(ctx, carrier) == carrier
    end

    test "facade extract/3 is a no-op when no propagator is configured" do
      carrier = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      ctx = Otel.API.Ctx.new()

      assert Otel.API.Propagator.TextMap.extract(ctx, carrier) == ctx
    end
  end
end
