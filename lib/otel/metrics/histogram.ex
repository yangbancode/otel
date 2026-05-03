defmodule Otel.Metrics.Histogram do
  @moduledoc """
  Synchronous Histogram instrument facade (OTel
  `metrics/api.md` §Histogram, Status: **Stable**,
  L735-L827).

  A Histogram reports arbitrary values that are likely to
  be statistically meaningful — intended for statistics
  such as histograms, summaries, and percentiles (spec
  L737-L739). Example uses: request duration, response
  payload size (spec L743-L744).

  Created exclusively through a `Meter` per spec L748
  *"MUST NOT be any API for creating a Histogram other
  than with a Meter"*.

  ## Non-negative value contract

  Per spec L797-L800, the recorded value is **expected to
  be non-negative**. The API:

  - SHOULD be documented to communicate the non-negative
    expectation (satisfied here)
  - SHOULD NOT validate — validation is the SDK's
    responsibility

  A negative value passed to `record/3` will be accepted
  at the API boundary and forwarded to the SDK.

  ## Advisory parameters

  The `:advisory` keyword accepts instrument-specific
  hints per §Instrument advisory parameters. For
  Histogram, the relevant hint is
  `explicit_bucket_boundaries` (bucket layout override).
  The API SHOULD NOT validate advisory parameters (spec
  L400 — same blanket rule across instruments).

  ## BEAM representation

  `opentelemetry-erlang` implements this as a `defmacro`
  that resolves the meter implicitly via
  `opentelemetry_experimental:get_meter/1` at expansion
  time and injects `OpenTelemetry.Ctx.get_current()` into
  `:otel_histogram.record/5`
  (`lib/open_telemetry/histogram.ex`). We take a different
  path:

  - plain `def` with an explicit `Meter.t()` handle —
    macro-free, Dialyzer-visible, consistent with the
    `Tracer` and `Meter` facades project-wide
  - no implicit context threaded through `record/3` —
    synchronous metric measurements are not
    context-associated at the API boundary; the SDK
    attaches context per `Otel.Ctx` if relevant


  All functions are safe for concurrent use (spec
  L1351-L1352, §Concurrency §Instrument).

  ## Public API

  | Function | Role |
  |---|---|
  | `create/3` | **Application** (OTel API MUST) — Histogram creation (L746-L777) |
  | `record/3` | **Application** (OTel API MUST) — Histogram Record (L781-L826) |

  ## References

  - OTel Metrics API §Histogram: `opentelemetry-specification/specification/metrics/api.md` L735-L827
  - OTel Metrics API §Synchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L302-L348
  - OTel Metrics API §Concurrency §Instrument: `opentelemetry-specification/specification/metrics/api.md` L1351-L1352
  """

  use Otel.Common.Types

  @doc """
  **Application** (OTel API MUST) — "Histogram creation"
  (`metrics/api.md` §Histogram creation, L746-L777).

  Creates the instrument handle via the given Meter. Per
  spec L748, there is no other API surface for creating a
  Histogram.

  Options (per §Synchronous Instrument API L302-L348):

  - `:unit` — case-sensitive ASCII string, max 63 chars
  - `:description` — opaque string (BMP Plane 0), at least
    1023 chars supported
  - `:advisory` — advisory parameters (e.g.
    `explicit_bucket_boundaries`)

  Delegates to `Otel.Metrics.Meter.create_histogram/3`.
  """
  @spec create(
          name :: String.t(),
          opts :: Otel.Metrics.Instrument.create_opts()
        ) :: Otel.Metrics.Instrument.t()
  def create(name, opts \\ []) do
    Otel.Metrics.Meter.create_histogram(name, opts)
  end

  @doc """
  **Application** (OTel API MUST) — "Record" (`metrics/api.md`
  §Histogram operations — Record, L781-L826).

  Updates the histogram statistics with `value`. Per spec
  L797-L800 the value is expected to be non-negative; the
  API does not validate (`SHOULD NOT validate` per spec —
  SDK's job).

  Attributes default to `%{}` per spec L801-L805 *"MUST be
  structured to accept a variable number of attributes,
  including none"*.


  Delegates to `Otel.Metrics.Meter.record/3` — both
  Histogram.record and the synchronous siblings share a
  single Meter dispatch.
  """
  @spec record(
          instrument :: Otel.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive_any()}
        ) :: :ok
  def record(instrument, value, attributes \\ %{}) do
    Otel.Metrics.Meter.record(instrument, value, attributes)
  end
end
