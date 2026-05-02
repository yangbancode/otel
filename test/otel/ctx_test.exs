defmodule Otel.CtxTest do
  use ExUnit.Case, async: false

  setup do
    # Clear any process-dictionary context left by other suites.
    Otel.Ctx.detach(Otel.Ctx.new())
    :ok
  end

  describe "create_key/1" do
    test "is identity over any term, and the returned key works with get/set_value" do
      assert Otel.Ctx.create_key(:span) == :span
      assert Otel.Ctx.create_key("custom") == "custom"
      assert Otel.Ctx.create_key({MyLib, :key}) == {MyLib, :key}

      key = Otel.Ctx.create_key({MyLib, :data})

      ctx = Otel.Ctx.set_value(Otel.Ctx.new(), key, "hello")
      assert Otel.Ctx.get_value(ctx, key) == "hello"
    end
  end

  describe "set_value/3 + get_value/2 on an explicit context" do
    test "round-trip; missing key returns nil" do
      ctx = Otel.Ctx.set_value(Otel.Ctx.new(), :key, "value")

      assert Otel.Ctx.get_value(ctx, :key) == "value"
      assert Otel.Ctx.get_value(ctx, :missing) == nil
    end

    test "context is immutable — set_value returns a new context" do
      ctx1 = Otel.Ctx.set_value(Otel.Ctx.new(), :a, 1)
      ctx2 = Otel.Ctx.set_value(ctx1, :b, 2)

      assert Otel.Ctx.get_value(ctx1, :a) == 1
      assert Otel.Ctx.get_value(ctx1, :b) == nil

      assert Otel.Ctx.get_value(ctx2, :a) == 1
      assert Otel.Ctx.get_value(ctx2, :b) == 2
    end
  end

  describe "current/0 + attach/1 + detach/1" do
    test "current/0 starts empty; attach/1 returns the previous context as a token" do
      assert Otel.Ctx.current() == Otel.Ctx.new()

      token = Otel.Ctx.attach(Otel.Ctx.set_value(Otel.Ctx.new(), :a, 1))
      assert token == Otel.Ctx.new()
      assert Otel.Ctx.get_value(Otel.Ctx.current(), :a) == 1
    end

    test "detach/1 restores the captured token" do
      original = Otel.Ctx.set_value(Otel.Ctx.new(), :a, 1)
      Otel.Ctx.attach(original)

      new_ctx = Otel.Ctx.set_value(Otel.Ctx.new(), :b, 2)
      token = Otel.Ctx.attach(new_ctx)
      assert Otel.Ctx.get_value(Otel.Ctx.current(), :b) == 2

      assert Otel.Ctx.detach(token) == :ok
      assert Otel.Ctx.get_value(Otel.Ctx.current(), :a) == 1
      assert Otel.Ctx.get_value(Otel.Ctx.current(), :b) == nil
    end
  end

  describe "set_value/2 + get_value/1 (implicit current)" do
    test "round-trip through the current context" do
      :ok = Otel.Ctx.set_value(:k, "v")
      assert Otel.Ctx.get_value(:k) == "v"
      assert Otel.Ctx.get_value(:missing) == nil
    end

    test "preserves unrelated keys across set_value/2 calls" do
      :ok = Otel.Ctx.set_value(:a, 1)
      :ok = Otel.Ctx.set_value(:b, 2)

      assert Otel.Ctx.get_value(:a) == 1
      assert Otel.Ctx.get_value(:b) == 2
    end
  end

  describe "cross-process" do
    test "current context does NOT propagate to a spawned process by default" do
      Otel.Ctx.attach(Otel.Ctx.set_value(Otel.Ctx.new(), :key, "parent"))

      child_ctx = Task.async(fn -> Otel.Ctx.current() end) |> Task.await()
      assert child_ctx == Otel.Ctx.new()
    end

    test "context can be passed explicitly into another process" do
      Otel.Ctx.attach(Otel.Ctx.set_value(Otel.Ctx.new(), :key, "parent"))
      parent_ctx = Otel.Ctx.current()

      child_ctx =
        Task.async(fn ->
          Otel.Ctx.attach(parent_ctx)
          Otel.Ctx.current()
        end)
        |> Task.await()

      assert Otel.Ctx.get_value(child_ctx, :key) == "parent"
    end
  end
end
