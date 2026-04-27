defmodule Otel.SDK.Config.EnvTest do
  use ExUnit.Case, async: false

  @var "OTEL_SDK_CONFIG_ENV_TEST"

  setup do
    on_exit(fn -> System.delete_env(@var) end)
    :ok
  end

  describe "string/1" do
    test "returns nil when unset" do
      assert Otel.SDK.Config.Env.string(@var) == nil
    end

    test "returns nil for empty string (spec L60 — empty MUST be unset)" do
      System.put_env(@var, "")
      assert Otel.SDK.Config.Env.string(@var) == nil
    end

    test "returns the raw value when set" do
      System.put_env(@var, "hello")
      assert Otel.SDK.Config.Env.string(@var) == "hello"
    end
  end

  describe "boolean/1" do
    test "true / TRUE / True all parse to true" do
      for raw <- ["true", "TRUE", "True"] do
        System.put_env(@var, raw)
        assert Otel.SDK.Config.Env.boolean(@var) == true
      end
    end

    test "false parses to false" do
      System.put_env(@var, "false")
      assert Otel.SDK.Config.Env.boolean(@var) == false
    end

    test "unparseable values fall to false (spec L66-L76)" do
      System.put_env(@var, "yes")
      assert Otel.SDK.Config.Env.boolean(@var) == false
    end

    test "returns nil when unset" do
      assert Otel.SDK.Config.Env.boolean(@var) == nil
    end
  end

  describe "integer/1" do
    test "parses valid integers" do
      System.put_env(@var, "42")
      assert Otel.SDK.Config.Env.integer(@var) == 42
    end

    test "parses negative integers" do
      System.put_env(@var, "-5")
      assert Otel.SDK.Config.Env.integer(@var) == -5
    end

    test "returns nil for unparseable values (spec L88-L90 SHOULD warn + ignore)" do
      System.put_env(@var, "abc")
      assert Otel.SDK.Config.Env.integer(@var) == nil
    end

    test "returns nil for trailing garbage" do
      System.put_env(@var, "10x")
      assert Otel.SDK.Config.Env.integer(@var) == nil
    end
  end

  describe "duration_ms/1" do
    test "accepts non-negative integers" do
      System.put_env(@var, "1000")
      assert Otel.SDK.Config.Env.duration_ms(@var) == 1000

      System.put_env(@var, "0")
      assert Otel.SDK.Config.Env.duration_ms(@var) == 0
    end

    test "rejects negative values (common.md L77-L82)" do
      System.put_env(@var, "-100")
      assert Otel.SDK.Config.Env.duration_ms(@var) == nil
    end
  end

  describe "timeout_ms/1" do
    test "0 means infinite (common.md L92-L102)" do
      System.put_env(@var, "0")
      assert Otel.SDK.Config.Env.timeout_ms(@var) == :infinity
    end

    test "positive values pass through" do
      System.put_env(@var, "5000")
      assert Otel.SDK.Config.Env.timeout_ms(@var) == 5000
    end

    test "negative values return nil" do
      System.put_env(@var, "-1")
      assert Otel.SDK.Config.Env.timeout_ms(@var) == nil
    end
  end

  describe "enum/2" do
    test "matches case-insensitively against allowed atoms" do
      System.put_env(@var, "OTLP")
      assert Otel.SDK.Config.Env.enum(@var, [:otlp, :console, :none]) == :otlp
    end

    test "returns nil for unknown values (spec L107 MUST warn + ignore)" do
      System.put_env(@var, "zipkin")
      assert Otel.SDK.Config.Env.enum(@var, [:otlp, :console, :none]) == nil
    end

    test "returns nil when unset" do
      assert Otel.SDK.Config.Env.enum(@var, [:otlp]) == nil
    end
  end

  describe "list/1" do
    test "splits on commas, trims whitespace, drops empties" do
      System.put_env(@var, "tracecontext, baggage ,")
      assert Otel.SDK.Config.Env.list(@var) == ["tracecontext", "baggage"]
    end

    test "returns nil when unset" do
      assert Otel.SDK.Config.Env.list(@var) == nil
    end
  end
end
