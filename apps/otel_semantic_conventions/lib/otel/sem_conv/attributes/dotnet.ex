defmodule Otel.SemConv.Attributes.Dotnet do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Dotnet attributes.
  """

  @typedoc """
  Name of the garbage collector managed heap generation.
  """
  @type dotnet_gc_heap_generation_values :: %{optional(String.t()) => String.t()}

  @doc """
  Name of the garbage collector managed heap generation.

      iex> Otel.SemConv.Attributes.Dotnet.dotnet_gc_heap_generation()
      "dotnet.gc.heap.generation"
  """
  @spec dotnet_gc_heap_generation :: String.t()
  def dotnet_gc_heap_generation do
    "dotnet.gc.heap.generation"
  end

  @doc """
  Enum values for `dotnet_gc_heap_generation`.

      iex> Otel.SemConv.Attributes.Dotnet.dotnet_gc_heap_generation_values()["gen0"]
      "gen0"
  """
  @spec dotnet_gc_heap_generation_values :: dotnet_gc_heap_generation_values()
  def dotnet_gc_heap_generation_values do
    %{
      "gen0" => "gen0",
      "gen1" => "gen1",
      "gen2" => "gen2",
      "loh" => "loh",
      "poh" => "poh"
    }
  end
end
