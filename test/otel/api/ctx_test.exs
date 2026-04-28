defmodule Otel.API.CtxTest do
  use ExUnit.Case, async: false

  setup do
    # Clear any process-dictionary context left by other suites.
    Otel.API.Ctx.detach(Otel.API.Ctx.new())
    :ok
  end

  describe "create_key/1" do
    test "is identity over any term, and the returned key works with get/set_value" do
      assert Otel.API.Ctx.create_key(:span) == :span
      assert Otel.API.Ctx.create_key("custom") == "custom"
      assert Otel.API.Ctx.create_key({MyLib, :key}) == {MyLib, :key}

      key = Otel.API.Ctx.create_key({MyLib, :data})

      ctx = Otel.API.Ctx.set_value(Otel.API.Ctx.new(), key, "hello")
      assert Otel.API.Ctx.get_value(ctx, key) == "hello"
    end
  end

  describe "set_value/3 + get_value/2 on an explicit context" do
    test "round-trip; missing key returns nil" do
      ctx = Otel.API.Ctx.set_value(Otel.API.Ctx.new(), :key, "value")

      assert Otel.API.Ctx.get_value(ctx, :key) == "value"
      assert Otel.API.Ctx.get_value(ctx, :missing) == nil
    end

    test "context is immutable — set_value returns a new context" do
      ctx1 = Otel.API.Ctx.set_value(Otel.API.Ctx.new(), :a, 1)
      ctx2 = Otel.API.Ctx.set_value(ctx1, :b, 2)

      assert Otel.API.Ctx.get_value(ctx1, :a) == 1
      assert Otel.API.Ctx.get_value(ctx1, :b) == nil

      assert Otel.API.Ctx.get_value(ctx2, :a) == 1
      assert Otel.API.Ctx.get_value(ctx2, :b) == 2
    end
  end

  describe "current/0 + attach/1 + detach/1" do
    test "current/0 starts empty; attach/1 returns the previous context as a token" do
      assert Otel.API.Ctx.current() == Otel.API.Ctx.new()

      token = Otel.API.Ctx.attach(Otel.API.Ctx.set_value(Otel.API.Ctx.new(), :a, 1))
      assert token == Otel.API.Ctx.new()
      assert Otel.API.Ctx.get_value(Otel.API.Ctx.current(), :a) == 1
    end

    test "detach/1 restores the captured token" do
      original = Otel.API.Ctx.set_value(Otel.API.Ctx.new(), :a, 1)
      Otel.API.Ctx.attach(original)

      new_ctx = Otel.API.Ctx.set_value(Otel.API.Ctx.new(), :b, 2)
      token = Otel.API.Ctx.attach(new_ctx)
      assert Otel.API.Ctx.get_value(Otel.API.Ctx.current(), :b) == 2

      assert Otel.API.Ctx.detach(token) == :ok
      assert Otel.API.Ctx.get_value(Otel.API.Ctx.current(), :a) == 1
      assert Otel.API.Ctx.get_value(Otel.API.Ctx.current(), :b) == nil
    end
  end

  describe "set_value/2 + get_value/1 (implicit current)" do
    test "round-trip through the current context" do
      :ok = Otel.API.Ctx.set_value(:k, "v")
      assert Otel.API.Ctx.get_value(:k) == "v"
      assert Otel.API.Ctx.get_value(:missing) == nil
    end

    test "preserves unrelated keys across set_value/2 calls" do
      :ok = Otel.API.Ctx.set_value(:a, 1)
      :ok = Otel.API.Ctx.set_value(:b, 2)

      assert Otel.API.Ctx.get_value(:a) == 1
      assert Otel.API.Ctx.get_value(:b) == 2
    end
  end

  describe "cross-process" do
    test "current context does NOT propagate to a spawned process by default" do
      Otel.API.Ctx.attach(Otel.API.Ctx.set_value(Otel.API.Ctx.new(), :key, "parent"))

      child_ctx = Task.async(fn -> Otel.API.Ctx.current() end) |> Task.await()
      assert child_ctx == Otel.API.Ctx.new()
    end

    test "context can be passed explicitly into another process" do
      Otel.API.Ctx.attach(Otel.API.Ctx.set_value(Otel.API.Ctx.new(), :key, "parent"))
      parent_ctx = Otel.API.Ctx.current()

      child_ctx =
        Task.async(fn ->
          Otel.API.Ctx.attach(parent_ctx)
          Otel.API.Ctx.current()
        end)
        |> Task.await()

      assert Otel.API.Ctx.get_value(child_ctx, :key) == "parent"
    end
  end
end
