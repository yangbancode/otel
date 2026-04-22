defmodule Otel.API.Trace.Span.Noop do
  @moduledoc """
  No-op Span operations implementation (OTel `trace/api.md`
  §"Behavior of the API in the absence of an installed SDK",
  L860-L874, Status: **Stable**).

  Spec summary (L862-L874) applied to Span mutations:

  > *"In general, in the absence of an installed SDK, the
  > Trace API is a 'no-op' API. This means that operations on
  > a Tracer, or on Spans, should have no side effects and
  > do nothing."*

  Start-span behaviour lives on `Otel.API.Trace.Tracer.Noop`
  (L865-L874 SpanContext-propagation exception); this module
  covers the 9 post-creation Span mutations. Each callback
  silently returns the shape the spec expects (`:ok` for
  mutations, `false` for `recording?/1`) with no state,
  no validation, no side effects.

  ## Why this module exists

  Unlike `Tracer` / `Meter` / `Logger` whose handles are
  `{module, config}` tuples — so `Provider.get_x/1` can hand
  out a `{Noop, []}` tuple and the facade pattern-matches on
  the module — `Span` takes a `SpanContext` handle that
  doesn't carry a dispatcher. `Otel.API.Trace.Span` resolves
  its SDK module through a module-level `:persistent_term`
  slot. Defaulting that slot to `Span.Noop` keeps the facade
  branchless (`get_module().set_attribute(...)` always dispatches to a
  valid module) and mirrors the project-wide Noop pattern
  established by `Tracer.Noop`, `Meter.Noop`, `Logger.Noop`,
  and `TextMap.Noop`.

  `opentelemetry-erlang`'s reference takes a different route
  — its `#span_ctx{span_sdk={Module, _}}` embeds the
  dispatcher in the SpanContext itself
  (`otel_span.erl` L156-L157), so Erlang doesn't need a
  dedicated `otel_span_noop` module (none exists). Our
  `SpanContext` is deliberately a pure W3C data value
  (`trace_id`, `span_id`, `trace_flags`, `tracestate`,
  `is_remote`) with no SDK field; `Span.Noop` fills the gap.

  All functions are safe for concurrent use.

  ## Public API

  | Function | Role |
  |---|---|
  | `recording?/1` | **SDK** (Noop implementation) — always `false` (L862-L863) |
  | `set_attribute/3` | **SDK** (Noop implementation) — discard attribute (L862-L863) |
  | `set_attributes/2` | **SDK** (Noop implementation) — discard attribute map (L862-L863) |
  | `add_event/2` | **SDK** (Noop implementation) — discard event (L862-L863) |
  | `add_link/2` | **SDK** (Noop implementation) — discard link (L862-L863) |
  | `set_status/2` | **SDK** (Noop implementation) — discard status (L862-L863) |
  | `update_name/2` | **SDK** (Noop implementation) — discard name change (L862-L863) |
  | `end_span/2` | **SDK** (Noop implementation) — discard end signal (L862-L863) |
  | `record_exception/4` | **SDK** (Noop implementation) — discard exception event (L862-L863) |

  ## References

  - OTel Trace API §Behavior in absence of SDK: `opentelemetry-specification/specification/trace/api.md` L860-L874
  - OTel Trace API §Span operations: `opentelemetry-specification/specification/trace/api.md` L449-L705
  """

  use Otel.API.Common.Types

  @behaviour Otel.API.Trace.Span

  @doc """
  **SDK** (Noop implementation) — `recording?/1` always returns
  `false` (`trace/api.md` L862-L863).
  """
  @impl true
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(_span_ctx) do
    false
  end

  @doc """
  **SDK** (Noop implementation) — `set_attribute/3` discards
  the attribute silently (`trace/api.md` L862-L863).
  """
  @impl true
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t(),
          value :: primitive() | [primitive()]
        ) :: :ok
  def set_attribute(_span_ctx, _key, _value) do
    :ok
  end

  @doc """
  **SDK** (Noop implementation) — `set_attributes/2` discards
  the attribute map silently (`trace/api.md` L862-L863).
  """
  @impl true
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def set_attributes(_span_ctx, _attributes) do
    :ok
  end

  @doc """
  **SDK** (Noop implementation) — `add_event/2` discards the
  event silently (`trace/api.md` L862-L863).
  """
  @impl true
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          event :: Otel.API.Trace.Event.t()
        ) :: :ok
  def add_event(_span_ctx, _event) do
    :ok
  end

  @doc """
  **SDK** (Noop implementation) — `add_link/2` discards the
  link silently (`trace/api.md` L862-L863).
  """
  @impl true
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          link :: Otel.API.Trace.Link.t()
        ) :: :ok
  def add_link(_span_ctx, _link) do
    :ok
  end

  @doc """
  **SDK** (Noop implementation) — `set_status/2` discards the
  status silently (`trace/api.md` L862-L863).
  """
  @impl true
  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          status :: Otel.API.Trace.Status.t()
        ) :: :ok
  def set_status(_span_ctx, _status) do
    :ok
  end

  @doc """
  **SDK** (Noop implementation) — `update_name/2` discards the
  name change silently (`trace/api.md` L862-L863).
  """
  @impl true
  @spec update_name(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          name :: String.t()
        ) :: :ok
  def update_name(_span_ctx, _name) do
    :ok
  end

  @doc """
  **SDK** (Noop implementation) — `end_span/2` discards the
  end signal silently (`trace/api.md` L862-L863).
  """
  @impl true
  @spec end_span(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          timestamp :: integer()
        ) :: :ok
  def end_span(_span_ctx, _timestamp) do
    :ok
  end

  @doc """
  **SDK** (Noop implementation) — `record_exception/4`
  discards the exception event silently (`trace/api.md`
  L862-L863).
  """
  @impl true
  @spec record_exception(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def record_exception(_span_ctx, _exception, _stacktrace, _attributes) do
    :ok
  end
end
