defmodule Otel.API.AttributesTest do
  use ExUnit.Case, async: true

  test "defines the collection type t" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.Attributes)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}
    assert {:type, :t} in names, "missing collection type t"
  end

  test "module has a moduledoc describing the collection" do
    {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Otel.API.Attributes)
    assert is_binary(moduledoc)
    assert String.contains?(moduledoc, "collection")
  end
end
