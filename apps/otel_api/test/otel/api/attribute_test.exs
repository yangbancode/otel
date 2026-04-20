defmodule Otel.API.AttributeTest do
  use ExUnit.Case, async: true

  test "defines all expected types" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.Attribute)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}

    for type <- [:key, :primitive, :value, :attributes] do
      assert {:type, type} in names, "missing type: #{type}"
    end
  end

  test "module has a moduledoc describing keys, values, and collection" do
    {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Otel.API.Attribute)
    assert is_binary(moduledoc)
    assert String.contains?(moduledoc, "key-value pair")
  end
end
