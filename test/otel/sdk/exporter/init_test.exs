defmodule Otel.SDK.Exporter.InitTest do
  use ExUnit.Case, async: true

  defmodule Ok do
    @moduledoc false
    def init(opts), do: {:ok, Map.put(opts, :ready, true)}
  end

  defmodule Ignore do
    @moduledoc false
    def init(_opts), do: :ignore
  end

  test "nil exporter passes through unchanged" do
    assert Otel.SDK.Exporter.Init.call(nil) == nil
  end

  test "{:ok, state} reply is wrapped as {module, state}" do
    assert {Ok, %{ready: true}} = Otel.SDK.Exporter.Init.call({Ok, %{}})
  end

  test ":ignore reply collapses to nil" do
    assert Otel.SDK.Exporter.Init.call({Ignore, %{}}) == nil
  end
end
