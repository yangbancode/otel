defmodule Otel.API.Trace.Status do
  @moduledoc """
  A Span's Status — spec: trace/api.md (Status).

  A Status is a code (`:unset`, `:ok`, or `:error`) plus an optional
  description. Per spec, `description` MUST only be used with the `:error`
  status code — it is ignored for `:unset` and `:ok` (L574, L599).
  """

  @type code :: :unset | :ok | :error

  @type t :: %__MODULE__{
          code: code(),
          description: String.t()
        }

  defstruct code: :unset, description: ""

  @doc """
  Creates a new Status.
  """
  @spec new(code :: code(), description :: String.t()) :: t()
  def new(code, description \\ "") do
    %__MODULE__{code: code, description: description}
  end
end
