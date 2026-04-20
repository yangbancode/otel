defmodule Otel.API.TypesTest do
  use ExUnit.Case, async: true

  test "use Otel.API.Types injects primitive and primitive_any into consumer" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.InstrumentationScope)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}

    for type <- [:primitive, :primitive_any] do
      assert {:type, type} in names, "missing type: #{type}"
    end
  end

  test "moduledoc explains primitive, primitive_any, and bytes tagging" do
    {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Otel.API.Types)
    assert is_binary(moduledoc)
    assert String.contains?(moduledoc, "primitive")
    assert String.contains?(moduledoc, "primitive_any")
    assert String.contains?(moduledoc, ":bytes")
  end
end
