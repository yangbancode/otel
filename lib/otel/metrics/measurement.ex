defmodule Otel.Metrics.Measurement do
  @moduledoc """
  A single numeric data point reported to the SDK (OTel
  `metrics/api.md` §Measurement, Status: **Stable**,
  L1278-L1287).

  A Measurement encapsulates a numeric value plus its
  associated attributes (spec L1284-L1287). Observable
  (asynchronous) instrument callbacks return a list of
  Measurements — spec L441-L442 *"Return a list (or tuple,
  generator, enumerator, etc.) of individual `Measurement`
  values"*. Synchronous recording APIs (`Counter.add/4`,
  `Histogram.record/4`, etc.) keep their `(value, attributes)`
  positional shape and do **not** use this struct — the
  callback-return path is the only place the handle flows
  across the API boundary as data.

  `opentelemetry-erlang` has **no** dedicated Measurement
  record; it passes raw `(value, attributes)` tuples. We
  model every multi-field spec entity in this project as a
  `defstruct` so `%Measurement{}` patterns carry the shape
  through Dialyzer.

  ## Construction

  Callers construct instances with the `%Measurement{...}`
  struct literal directly:

      %Otel.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}

  This module provides **no** constructor function. A
  ceremonial `new/2` was removed because it carried no
  runtime default (the `attributes: %{}` default already
  lives on `defstruct`), no spec enforcement
  (§Measurement has no MUST/SHOULD to wrap), and no
  validation (happy-path policy per
  `.claude/rules/code-conventions.md`). Contrast
  `Event.new/3` (which supplies
  `System.system_time(:nanosecond)`) and `Status.new/2`
  (which enforces spec L599 "Description MUST be IGNORED
  for `:ok` / `:unset`") — both carry real work. This
  module does not.

  ## References

  - OTel Metrics API §Measurement: `opentelemetry-specification/specification/metrics/api.md` L1278-L1287
  - OTel Metrics API §Async callback shape: `opentelemetry-specification/specification/metrics/api.md` L441-L442
  """

  use Otel.Common.Types

  @typedoc """
  A Measurement struct (spec `metrics/api.md` §Measurement,
  L1278-L1287).

  Fields:

  - `value` — the numeric data point. `t:number/0` covers
    both integer and float variants the OTel metric
    instruments accept.
  - `attributes` — an `%{String.t() => primitive_any()}`
    map associated with the measurement. Values follow OTel
    attribute rules (primitives and homogeneous arrays; no
    maps, no heterogeneous arrays).
  """
  @type t :: %__MODULE__{
          value: number(),
          attributes: %{String.t() => primitive_any()}
        }

  defstruct value: 0, attributes: %{}
end
