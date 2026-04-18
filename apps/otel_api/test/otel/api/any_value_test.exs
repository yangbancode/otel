defmodule Otel.API.AnyValueTest do
  use ExUnit.Case, async: true

  test "defines the t type" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.AnyValue)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}
    assert {:type, :t} in names
  end

  test "module has a moduledoc" do
    {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Otel.API.AnyValue)
    assert is_binary(moduledoc)
    assert String.contains?(moduledoc, "AnyValue")
  end
end
