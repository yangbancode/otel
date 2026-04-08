defmodule OtelTest do
  use ExUnit.Case
  doctest Otel

  test "greets the world" do
    assert Otel.hello() == :world
  end
end
