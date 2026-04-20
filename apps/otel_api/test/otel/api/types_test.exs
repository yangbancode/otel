defmodule Otel.API.TypesTest do
  use ExUnit.Case, async: true

  test "defines primitive and any_value" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.Types)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}

    for type <- [:primitive, :any_value] do
      assert {:type, type} in names, "missing type: #{type}"
    end
  end

  test "moduledoc explains primitive, any_value, and bytes tagging" do
    {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Otel.API.Types)
    assert is_binary(moduledoc)
    assert String.contains?(moduledoc, "primitive")
    assert String.contains?(moduledoc, "any_value")
    assert String.contains?(moduledoc, ":bytes")
  end
end
