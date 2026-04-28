defmodule Otel.API.Common.TypesTest do
  use ExUnit.Case, async: true

  # `Otel.API.InstrumentationScope` is one of the modules that
  # `use Otel.API.Common.Types`; verify the use-block injects the
  # `primitive/0` and `primitive_any/0` typespecs the consumer can
  # then reference in its own `@type` / `@spec`.
  test "use Otel.API.Common.Types injects primitive + primitive_any types" do
    {:ok, types} = Code.Typespec.fetch_types(Otel.API.InstrumentationScope)
    names = for {kind, {name, _, _}} <- types, do: {kind, name}

    assert {:type, :primitive} in names
    assert {:type, :primitive_any} in names
  end
end
