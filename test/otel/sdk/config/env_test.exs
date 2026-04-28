defmodule Otel.SDK.Config.EnvTest do
  use ExUnit.Case, async: false

  @var "OTEL_SDK_CONFIG_ENV_TEST"

  setup do
    on_exit(fn -> System.delete_env(@var) end)
    :ok
  end

  defp put(value), do: System.put_env(@var, value)

  # Spec sdk-environment-variables.md L60 — empty value MUST be
  # treated as unset (returns nil).
  test "string/1 — returns nil when unset or empty; raw value otherwise" do
    assert Otel.SDK.Config.Env.string(@var) == nil
    put("")
    assert Otel.SDK.Config.Env.string(@var) == nil
    put("hello")
    assert Otel.SDK.Config.Env.string(@var) == "hello"
  end

  # Spec L66-L76 — only "true" (case-insensitive) parses to true;
  # everything else (including "yes") is false; unset is nil.
  test "boolean/1 — case-insensitive true; everything else false; nil when unset" do
    for raw <- ["true", "TRUE", "True"] do
      put(raw)
      assert Otel.SDK.Config.Env.boolean(@var) == true
    end

    put("false")
    assert Otel.SDK.Config.Env.boolean(@var) == false
    put("yes")
    assert Otel.SDK.Config.Env.boolean(@var) == false

    System.delete_env(@var)
    assert Otel.SDK.Config.Env.boolean(@var) == nil
  end

  # Spec L88-L90 — unparseable integers SHOULD warn + be ignored (→ nil).
  test "integer/1 — parses signed ints; nil for unparseable / trailing garbage" do
    put("42")
    assert Otel.SDK.Config.Env.integer(@var) == 42
    put("-5")
    assert Otel.SDK.Config.Env.integer(@var) == -5
    put("abc")
    assert Otel.SDK.Config.Env.integer(@var) == nil
    put("10x")
    assert Otel.SDK.Config.Env.integer(@var) == nil
  end

  # Spec common.md L77-L82 — duration must be non-negative.
  test "duration_ms/1 — non-negative integers pass through; negatives → nil" do
    put("1000")
    assert Otel.SDK.Config.Env.duration_ms(@var) == 1000
    put("0")
    assert Otel.SDK.Config.Env.duration_ms(@var) == 0
    put("-100")
    assert Otel.SDK.Config.Env.duration_ms(@var) == nil
  end

  # Spec common.md L92-L102 — timeout 0 means infinite.
  test "timeout_ms/1 — 0 → :infinity, positive passes through, negative → nil" do
    put("0")
    assert Otel.SDK.Config.Env.timeout_ms(@var) == :infinity
    put("5000")
    assert Otel.SDK.Config.Env.timeout_ms(@var) == 5000
    put("-1")
    assert Otel.SDK.Config.Env.timeout_ms(@var) == nil
  end

  # Spec L107 — unknown enum value MUST warn + be ignored.
  test "enum/2 — case-insensitive match; unknown / unset → nil" do
    put("OTLP")
    assert Otel.SDK.Config.Env.enum(@var, [:otlp, :console, :none]) == :otlp
    put("zipkin")
    assert Otel.SDK.Config.Env.enum(@var, [:otlp, :console, :none]) == nil

    System.delete_env(@var)
    assert Otel.SDK.Config.Env.enum(@var, [:otlp]) == nil
  end

  test "list/1 — comma-split, trims whitespace, drops empties; nil when unset" do
    put("tracecontext, baggage ,")
    assert Otel.SDK.Config.Env.list(@var) == ["tracecontext", "baggage"]

    System.delete_env(@var)
    assert Otel.SDK.Config.Env.list(@var) == nil
  end
end
