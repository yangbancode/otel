defmodule Otel.API.AttributeTest do
  use ExUnit.Case, async: true

  test "defines singular types key, scalar, value" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.Attribute)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}

    for type <- [:key, :scalar, :value] do
      assert {:type, type} in names, "missing type: #{type}"
    end
  end

  test "module has a moduledoc describing single-attribute types" do
    {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Otel.API.Attribute)
    assert is_binary(moduledoc)
    assert String.contains?(moduledoc, "single attribute")
  end
end
