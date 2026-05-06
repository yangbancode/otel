defmodule Otel.Trace.Status do
  @moduledoc """
  A Span's Status (spec `trace/api.md` §Set Status, Status:
  **Stable**).

  A Status is a code (`:unset`, `:ok`, or `:error`) plus an
  optional description. Per spec L574 *"Description MUST only
  be used with the Error StatusCode value"* and L599-L600
  *"Description MUST be IGNORED for StatusCode Ok & Unset
  values"* — `new/2` enforces this by discarding the
  description for non-`:error` codes.
  `opentelemetry-erlang`'s `opentelemetry:status/2` applies
  the same rule because both implementations follow the spec
  mandate.

  Per spec L590-L592 the codes form a total order
  `Ok > Error > Unset`: setting `:ok` overrides prior/future
  attempts to set `:error` or `:unset`. That ordering is
  enforced at the Span level (the `SetStatus` call site), not
  by this type module.

  ## Public API

  | Function | Role |
  |---|---|
  | `new/2` | **Application** (Convenience) — Build a Status struct |

  ## References

  - OTel Trace API §Set Status: `opentelemetry-specification/specification/trace/api.md` L565-L610
  """

  @typedoc """
  A Span status code (spec `trace/api.md` L580-L588).

  - `:unset` — default; no explicit status set.
  - `:ok` — the operation has been validated by the developer
    or operator to have completed successfully.
  - `:error` — the operation contains an error; pair with a
    `description` to explain.
  """
  @type code :: :unset | :ok | :error

  @typedoc """
  A Span Status struct (spec `trace/api.md` §Set Status,
  L570-L575).

  Fields:

  - `code` — one of `:unset`, `:ok`, `:error`.
  - `description` — human-readable message. Per spec L574 only
    meaningful when `code == :error`; for `:ok` / `:unset` the
    field is kept empty to honour the MUST IGNORE rule
    (L599-L600). An empty `description` is equivalent to a
    not-present one (spec L575).
  """
  @type t :: %__MODULE__{
          code: code(),
          description: String.t()
        }

  defstruct [:code, :description]

  @doc """
  **Application** (Convenience) — Build a Status struct for
  `Otel.Trace.Span.set_status/2`.

  Per spec L599-L600 *"Description MUST be IGNORED for StatusCode
  Ok & Unset values"* — only `:error` preserves `description`;
  `:ok` and `:unset` discard it.

  Per spec L575 an empty `description` is equivalent to a
  not-present one, so the default `""` is a natural
  no-description sentinel.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    merged = Map.merge(%{code: :unset, description: ""}, opts)
    description = if merged.code == :error, do: merged.description, else: ""
    struct!(__MODULE__, %{code: merged.code, description: description})
  end
end
