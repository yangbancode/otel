defmodule Otel.API.CtxTest do
  use ExUnit.Case, async: false

  describe "create_key/1" do
    test "returns the name unchanged (identity)" do
      assert Otel.API.Ctx.create_key(:span) == :span
      assert Otel.API.Ctx.create_key("custom") == "custom"
      assert Otel.API.Ctx.create_key({MyLib, :key}) == {MyLib, :key}
    end

    test "keys work with get_value/set_value" do
      key = Otel.API.Ctx.create_key(:my_key)
      ctx = Otel.API.Ctx.set_value(%{}, key, "hello")
      assert Otel.API.Ctx.get_value(ctx, key) == "hello"
    end

    test "caller-supplied distinct names produce distinct keys" do
      key1 = Otel.API.Ctx.create_key({MyLib, :data, 1})
      key2 = Otel.API.Ctx.create_key({MyLib, :data, 2})
      ctx = %{}
      ctx = Otel.API.Ctx.set_value(ctx, key1, "from_a")
      ctx = Otel.API.Ctx.set_value(ctx, key2, "from_b")
      assert Otel.API.Ctx.get_value(ctx, key1) == "from_a"
      assert Otel.API.Ctx.get_value(ctx, key2) == "from_b"
    end
  end

  describe "get_value/2 and set_value/3" do
    test "set_value/3 returns new context with value" do
      ctx = Otel.API.Ctx.set_value(%{}, :key, "value")
      assert ctx == %{key: "value"}
    end

    test "get_value/2 returns value for key" do
      ctx = %{key: "value"}
      assert Otel.API.Ctx.get_value(ctx, :key) == "value"
    end

    test "get_value/2 returns nil when key missing" do
      assert Otel.API.Ctx.get_value(%{}, :missing) == nil
    end

    test "caller composes default via || operator" do
      assert (Otel.API.Ctx.get_value(%{}, :missing) || :default) == :default
      assert (Otel.API.Ctx.get_value(%{key: "v"}, :key) || :default) == "v"
    end

    test "context is immutable — set_value returns new map" do
      ctx1 = %{a: 1}
      ctx2 = Otel.API.Ctx.set_value(ctx1, :b, 2)
      assert ctx1 == %{a: 1}
      assert ctx2 == %{a: 1, b: 2}
    end
  end

  describe "current/0, attach/1, detach/1" do
    setup do
      Otel.API.Ctx.detach(%{})
      :ok
    end

    test "current/0 returns an empty map in the initial state" do
      assert Otel.API.Ctx.current() == %{}
    end

    test "attach/1 sets current context and returns previous as map" do
      ctx = %{span: :my_span}
      token = Otel.API.Ctx.attach(ctx)
      assert Otel.API.Ctx.current() == ctx
      assert is_map(token)
    end

    test "attach/1 on fresh process returns empty map (not nil)" do
      token = Otel.API.Ctx.attach(%{a: 1})
      assert token == %{}
    end

    test "detach/1 returns :ok" do
      token = Otel.API.Ctx.attach(%{a: 1})
      assert Otel.API.Ctx.detach(token) == :ok
    end

    test "detach/1 restores previous context" do
      original = %{a: 1}
      Otel.API.Ctx.attach(original)

      new_ctx = %{b: 2}
      token = Otel.API.Ctx.attach(new_ctx)
      assert Otel.API.Ctx.current() == new_ctx

      Otel.API.Ctx.detach(token)
      assert Otel.API.Ctx.current() == original
    end
  end

  describe "get_value/1 and set_value/2 (implicit current)" do
    setup do
      Otel.API.Ctx.detach(%{})
      :ok
    end

    test "set_value/2 then get_value/1 round-trips through current" do
      :ok = Otel.API.Ctx.set_value(:key, "hello")
      assert Otel.API.Ctx.get_value(:key) == "hello"
    end

    test "get_value/1 returns nil when key missing" do
      assert Otel.API.Ctx.get_value(:missing) == nil
    end

    test "set_value/2 preserves unrelated keys" do
      :ok = Otel.API.Ctx.set_value(:a, 1)
      :ok = Otel.API.Ctx.set_value(:b, 2)
      assert Otel.API.Ctx.current() == %{a: 1, b: 2}
    end

    test "set_value/2 equivalent to current |> set_value/3 |> attach" do
      :ok = Otel.API.Ctx.set_value(:k, "v")

      explicit =
        %{}
        |> Otel.API.Ctx.set_value(:k, "v")

      assert Otel.API.Ctx.current() == explicit
    end
  end

  describe "cross-process" do
    test "context does not propagate to spawned process automatically" do
      Otel.API.Ctx.attach(%{key: "parent"})

      task =
        Task.async(fn ->
          Otel.API.Ctx.current()
        end)

      child_ctx = Task.await(task)
      assert child_ctx == %{}
    end

    test "context can be passed explicitly to another process" do
      Otel.API.Ctx.attach(%{key: "parent"})
      parent_ctx = Otel.API.Ctx.current()

      task =
        Task.async(fn ->
          Otel.API.Ctx.attach(parent_ctx)
          Otel.API.Ctx.current()
        end)

      child_ctx = Task.await(task)
      assert child_ctx == %{key: "parent"}
    end
  end
end
