defmodule Otel.SDK.Exporter.Init do
  @moduledoc """
  Centralised one-shot exporter initialisation.

  Every Trace SpanProcessor, Logs LogRecordProcessor, and Metrics
  MetricReader threads its user-supplied exporter through this
  helper at GenServer / gen_statem `init/1` time so that:

  - the exporter's own `init/1` runs **exactly once** at startup;
  - `{:ok, state}` becomes `{module, state}` and is stored as the
    per-call exporter handle;
  - `:ignore` becomes `nil`, normalising the "no active exporter"
    case for the rest of the processor's code paths.

  Mirrors erlang's `otel_exporter:init/1` in
  `references/opentelemetry-erlang/apps/opentelemetry/src/otel_exporter.erl`.
  Without a single shared point, each processor / reader was
  duplicating the same `case ... do {:ok, state} -> ...; :ignore
  -> nil end` shape — and `MetricReader.PeriodicExporting`
  silently skipped the `init/1` call entirely until the e2e smoke
  test in #392 surfaced it (see this commit's parent fix).
  """

  @type exporter :: {module(), term()}

  @spec call(exporter :: exporter() | nil) :: exporter() | nil
  def call(nil), do: nil

  def call({module, opts}) do
    case module.init(opts) do
      {:ok, state} -> {module, state}
      :ignore -> nil
    end
  end
end
