defmodule Otel.API.CtxTest do
  use ExUnit.Case, async: true

  describe "create_key/1" do
    test "returns a tuple with name and reference" do
      {name, ref} = Otel.API.Ctx.create_key("test")
      assert name == "test"
      assert is_reference(ref)
    end

    test "accepts atom name" do
      {name, ref} = Otel.API.Ctx.create_key(:span)
      assert name == :span
      assert is_reference(ref)
    end

    test "same name returns different keys" do
      key1 = Otel.API.Ctx.create_key("span")
      key2 = Otel.API.Ctx.create_key("span")
      assert key1 != key2
    end

    test "keys work with get_value/set_value" do
      key = Otel.API.Ctx.create_key("my_key")
      ctx = Otel.API.Ctx.set_value(Otel.API.Ctx.new(), key, "hello")
      assert Otel.API.Ctx.get_value(ctx, key, nil) == "hello"
    end

    test "different keys with same name do not collide" do
      key1 = Otel.API.Ctx.create_key("data")
      key2 = Otel.API.Ctx.create_key("data")
      ctx = Otel.API.Ctx.new()
      ctx = Otel.API.Ctx.set_value(ctx, key1, "from_a")
      ctx = Otel.API.Ctx.set_value(ctx, key2, "from_b")
      assert Otel.API.Ctx.get_value(ctx, key1, nil) == "from_a"
      assert Otel.API.Ctx.get_value(ctx, key2, nil) == "from_b"
    end
  end

  describe "new/0" do
    test "returns empty map" do
      assert Otel.API.Ctx.new() == %{}
    end
  end

  describe "explicit context operations" do
    test "set_value/3 returns new context with value" do
      ctx = Otel.API.Ctx.new()
      ctx = Otel.API.Ctx.set_value(ctx, :key, "value")
      assert ctx == %{key: "value"}
    end

    test "get_value/3 returns value for key" do
      ctx = %{key: "value"}
      assert Otel.API.Ctx.get_value(ctx, :key, nil) == "value"
    end

    test "get_value/3 returns default when key missing" do
      ctx = %{}
      assert Otel.API.Ctx.get_value(ctx, :key, :default) == :default
    end

    test "remove/2 removes key from context" do
      ctx = %{a: 1, b: 2}
      assert Otel.API.Ctx.remove(ctx, :a) == %{b: 2}
    end

    test "clear/1 returns empty context" do
      ctx = %{a: 1, b: 2}
      assert Otel.API.Ctx.clear(ctx) == %{}
    end

    test "context is immutable — set_value returns new map" do
      ctx1 = %{a: 1}
      ctx2 = Otel.API.Ctx.set_value(ctx1, :b, 2)
      assert ctx1 == %{a: 1}
      assert ctx2 == %{a: 1, b: 2}
    end
  end

  describe "implicit context operations" do
    setup do
      Otel.API.Ctx.clear()
      :ok
    end

    test "set_value/2 and get_value/1 on current process" do
      Otel.API.Ctx.set_value(:key, "value")
      assert Otel.API.Ctx.get_value(:key) == "value"
    end

    test "get_value/1 returns nil for missing key" do
      assert Otel.API.Ctx.get_value(:missing) == nil
    end

    test "get_value/2 returns default for missing key" do
      assert Otel.API.Ctx.get_value(:missing, :default) == :default
    end

    test "remove/1 removes key from current context" do
      Otel.API.Ctx.set_value(:key, "value")
      Otel.API.Ctx.remove(:key)
      assert Otel.API.Ctx.get_value(:key) == nil
    end

    test "remove/1 is safe when no context exists" do
      assert Otel.API.Ctx.remove(:key) == :ok
    end

    test "clear/0 removes all values" do
      Otel.API.Ctx.set_value(:a, 1)
      Otel.API.Ctx.set_value(:b, 2)
      Otel.API.Ctx.clear()
      assert Otel.API.Ctx.get_current() == %{}
    end
  end

  describe "attach/detach" do
    setup do
      Otel.API.Ctx.clear()
      :ok
    end

    test "attach/1 sets current context and returns previous" do
      ctx = %{span: :my_span}
      token = Otel.API.Ctx.attach(ctx)
      assert Otel.API.Ctx.get_current() == ctx
      assert token == nil || is_map(token)
    end

    test "detach/1 restores previous context" do
      original = %{a: 1}
      Otel.API.Ctx.attach(original)

      new_ctx = %{b: 2}
      token = Otel.API.Ctx.attach(new_ctx)
      assert Otel.API.Ctx.get_current() == new_ctx

      Otel.API.Ctx.detach(token)
      assert Otel.API.Ctx.get_current() == original
    end

    test "get_current/0 returns empty map when no context attached" do
      assert Otel.API.Ctx.get_current() == %{}
    end
  end

  describe "cross-process" do
    test "context does not propagate to spawned process automatically" do
      Otel.API.Ctx.attach(%{key: "parent"})

      task =
        Task.async(fn ->
          Otel.API.Ctx.get_current()
        end)

      child_ctx = Task.await(task)
      assert child_ctx == %{}
    end

    test "context can be passed explicitly to another process" do
      Otel.API.Ctx.attach(%{key: "parent"})
      parent_ctx = Otel.API.Ctx.get_current()

      task =
        Task.async(fn ->
          Otel.API.Ctx.attach(parent_ctx)
          Otel.API.Ctx.get_current()
        end)

      child_ctx = Task.await(task)
      assert child_ctx == %{key: "parent"}
    end
  end
end
