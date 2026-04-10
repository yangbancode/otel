defmodule Otel.API.CtxTest do
  use ExUnit.Case, async: true

  alias Otel.API.Ctx

  describe "new/0" do
    test "returns empty map" do
      assert Ctx.new() == %{}
    end
  end

  describe "explicit context operations" do
    test "set_value/3 returns new context with value" do
      ctx = Ctx.new()
      ctx = Ctx.set_value(ctx, :key, "value")
      assert ctx == %{key: "value"}
    end

    test "set_value/3 with non-map context creates new map" do
      ctx = Ctx.set_value(nil, :key, "value")
      assert ctx == %{key: "value"}
    end

    test "get_value/3 returns value for key" do
      ctx = %{key: "value"}
      assert Ctx.get_value(ctx, :key, nil) == "value"
    end

    test "get_value/3 returns default when key missing" do
      ctx = %{}
      assert Ctx.get_value(ctx, :key, :default) == :default
    end

    test "get_value/3 returns default for non-map context" do
      assert Ctx.get_value(nil, :key, :default) == :default
    end

    test "remove/2 removes key from context" do
      ctx = %{a: 1, b: 2}
      assert Ctx.remove(ctx, :a) == %{b: 2}
    end

    test "remove/2 with non-map returns empty context" do
      assert Ctx.remove(nil, :key) == %{}
    end

    test "clear/1 returns empty context" do
      ctx = %{a: 1, b: 2}
      assert Ctx.clear(ctx) == %{}
    end

    test "context is immutable — set_value returns new map" do
      ctx1 = %{a: 1}
      ctx2 = Ctx.set_value(ctx1, :b, 2)
      assert ctx1 == %{a: 1}
      assert ctx2 == %{a: 1, b: 2}
    end
  end

  describe "implicit context operations" do
    setup do
      Ctx.clear()
      :ok
    end

    test "set_value/2 and get_value/1 on current process" do
      Ctx.set_value(:key, "value")
      assert Ctx.get_value(:key) == "value"
    end

    test "get_value/1 returns nil for missing key" do
      assert Ctx.get_value(:missing) == nil
    end

    test "get_value/2 returns default for missing key" do
      assert Ctx.get_value(:missing, :default) == :default
    end

    test "remove/1 removes key from current context" do
      Ctx.set_value(:key, "value")
      Ctx.remove(:key)
      assert Ctx.get_value(:key) == nil
    end

    test "remove/1 is safe when no context exists" do
      assert Ctx.remove(:key) == :ok
    end

    test "clear/0 removes all values" do
      Ctx.set_value(:a, 1)
      Ctx.set_value(:b, 2)
      Ctx.clear()
      assert Ctx.get_current() == %{}
    end
  end

  describe "attach/detach" do
    setup do
      Ctx.clear()
      :ok
    end

    test "attach/1 sets current context and returns previous" do
      ctx = %{span: :my_span}
      token = Ctx.attach(ctx)
      assert Ctx.get_current() == ctx
      assert token == nil || is_map(token)
    end

    test "detach/1 restores previous context" do
      original = %{a: 1}
      Ctx.attach(original)

      new_ctx = %{b: 2}
      token = Ctx.attach(new_ctx)
      assert Ctx.get_current() == new_ctx

      Ctx.detach(token)
      assert Ctx.get_current() == original
    end

    test "get_current/0 returns empty map when no context attached" do
      assert Ctx.get_current() == %{}
    end
  end

  describe "cross-process" do
    test "context does not propagate to spawned process automatically" do
      Ctx.attach(%{key: "parent"})

      task =
        Task.async(fn ->
          Ctx.get_current()
        end)

      child_ctx = Task.await(task)
      assert child_ctx == %{}
    end

    test "context can be passed explicitly to another process" do
      Ctx.attach(%{key: "parent"})
      parent_ctx = Ctx.get_current()

      task =
        Task.async(fn ->
          Ctx.attach(parent_ctx)
          Ctx.get_current()
        end)

      child_ctx = Task.await(task)
      assert child_ctx == %{key: "parent"}
    end
  end
end
