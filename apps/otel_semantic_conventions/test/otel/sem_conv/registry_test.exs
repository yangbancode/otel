defmodule Otel.SemConv.RegistryTest do
  use ExUnit.Case, async: true

  {:ok, modules} = :application.get_key(:otel_semantic_conventions, :modules)

  for module <- modules,
      module_string = Atom.to_string(module),
      String.starts_with?(module_string, "Elixir.Otel.SemConv.Attributes.") or
        String.starts_with?(module_string, "Elixir.Otel.SemConv.Metrics.") do
    doctest module
  end
end
