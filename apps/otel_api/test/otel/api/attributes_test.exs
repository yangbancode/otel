defmodule Otel.API.AttributesTest do
  use ExUnit.Case, async: true

  test "defines all expected types" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.Attributes)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}

    for type <- [:key, :scalar, :value, :t] do
      assert {:type, type} in names, "missing type: #{type}"
    end
  end

  test "module has a moduledoc describing key, value, and collection" do
    {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Otel.API.Attributes)
    assert is_binary(moduledoc)
    assert String.contains?(moduledoc, "key-value pair")
  end
end
