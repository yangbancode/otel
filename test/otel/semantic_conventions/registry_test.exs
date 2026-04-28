defmodule Otel.SemanticConventions.RegistryTest do
  use ExUnit.Case, async: true

  {:ok, modules} = :application.get_key(:otel, :modules)

  for module <- modules,
      module_string = Atom.to_string(module),
      String.starts_with?(module_string, "Elixir.Otel.SemanticConventions.Attributes.") or
        String.starts_with?(module_string, "Elixir.Otel.SemanticConventions.Metrics.") do
    doctest module
  end
end
