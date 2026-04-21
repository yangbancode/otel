defmodule Otel.API.CtxTest do
  use ExUnit.Case, async: false

  alias Otel.API.Ctx

  describe "create_key/1" do
    test "returns the name unchanged (identity)" do
      assert Ctx.create_key(:span) == :span
      assert Ctx.create_key("custom") == "custom"
      assert Ctx.create_key({MyLib, :key}) == {MyLib, :key}
    end

    test "keys work with get_value/set_value" do
      key = Ctx.create_key(:my_key)
      ctx = Ctx.new() |> Ctx.set_value(key, "hello")
      assert Ctx.get_value(ctx, key) == "hello"
    end

    test "caller-supplied distinct names produce distinct keys" do
      key1 = Ctx.create_key({MyLib, :data, 1})
      key2 = Ctx.create_key({MyLib, :data, 2})

      ctx =
        Ctx.new()
        |> Ctx.set_value(key1, "from_a")
        |> Ctx.set_value(key2, "from_b")

      assert Ctx.get_value(ctx, key1) == "from_a"
      assert Ctx.get_value(ctx, key2) == "from_b"
    end
  end

  describe "get_value/2 and set_value/3" do
    test "set_value/3 stores the value under the key" do
      ctx = Ctx.new() |> Ctx.set_value(:key, "value")
      assert Ctx.get_value(ctx, :key) == "value"
    end

    test "get_value/2 returns nil when key missing" do
      assert Ctx.get_value(Ctx.new(), :missing) == nil
    end

    test "caller composes default via || operator" do
      assert (Ctx.get_value(Ctx.new(), :missing) || :default) == :default

      ctx = Ctx.new() |> Ctx.set_value(:key, "v")
      assert (Ctx.get_value(ctx, :key) || :default) == "v"
    end

    test "context is immutable — set_value returns a new context" do
      ctx1 = Ctx.new() |> Ctx.set_value(:a, 1)
      ctx2 = Ctx.set_value(ctx1, :b, 2)

      # ctx1 unchanged
      assert Ctx.get_value(ctx1, :a) == 1
      assert Ctx.get_value(ctx1, :b) == nil

      # ctx2 has both
      assert Ctx.get_value(ctx2, :a) == 1
      assert Ctx.get_value(ctx2, :b) == 2
    end
  end

  describe "current/0, attach/1, detach/1" do
    setup do
      Ctx.detach(Ctx.new())
      :ok
    end

    test "current/0 returns an empty context in the initial state" do
      assert Ctx.current() == Ctx.new()
    end

    test "attach/1 sets current context and returns previous as token" do
      ctx = Ctx.new() |> Ctx.set_value(:span, :my_span)
      _token = Ctx.attach(ctx)

      assert Ctx.get_value(Ctx.current(), :span) == :my_span
    end

    test "attach/1 on fresh process returns an empty token" do
      token = Ctx.attach(Ctx.new() |> Ctx.set_value(:a, 1))
      assert token == Ctx.new()
    end

    test "detach/1 returns :ok" do
      token = Ctx.attach(Ctx.new() |> Ctx.set_value(:a, 1))
      assert Ctx.detach(token) == :ok
    end

    test "detach/1 restores previous context" do
      original = Ctx.new() |> Ctx.set_value(:a, 1)
      Ctx.attach(original)

      new_ctx = Ctx.new() |> Ctx.set_value(:b, 2)
      token = Ctx.attach(new_ctx)
      assert Ctx.get_value(Ctx.current(), :b) == 2

      Ctx.detach(token)
      assert Ctx.get_value(Ctx.current(), :a) == 1
      assert Ctx.get_value(Ctx.current(), :b) == nil
    end
  end

  describe "get_value/1 and set_value/2 (implicit current)" do
    setup do
      Ctx.detach(Ctx.new())
      :ok
    end

    test "set_value/2 then get_value/1 round-trips through current" do
      :ok = Ctx.set_value(:key, "hello")
      assert Ctx.get_value(:key) == "hello"
    end

    test "get_value/1 returns nil when key missing" do
      assert Ctx.get_value(:missing) == nil
    end

    test "set_value/2 preserves unrelated keys" do
      :ok = Ctx.set_value(:a, 1)
      :ok = Ctx.set_value(:b, 2)

      assert Ctx.get_value(:a) == 1
      assert Ctx.get_value(:b) == 2
    end

    test "set_value/2 equivalent to current |> set_value/3 |> attach" do
      :ok = Ctx.set_value(:k, "v")
      assert Ctx.get_value(:k) == "v"
    end
  end

  describe "cross-process" do
    test "context does not propagate to spawned process automatically" do
      Ctx.attach(Ctx.new() |> Ctx.set_value(:key, "parent"))

      task =
        Task.async(fn ->
          Ctx.current()
        end)

      child_ctx = Task.await(task)
      assert child_ctx == Ctx.new()
    end

    test "context can be passed explicitly to another process" do
      Ctx.attach(Ctx.new() |> Ctx.set_value(:key, "parent"))
      parent_ctx = Ctx.current()

      task =
        Task.async(fn ->
          Ctx.attach(parent_ctx)
          Ctx.current()
        end)

      child_ctx = Task.await(task)
      assert Ctx.get_value(child_ctx, :key) == "parent"
    end
  end
end
