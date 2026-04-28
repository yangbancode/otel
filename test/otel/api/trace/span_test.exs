defmodule Otel.API.Trace.SpanTest do
  use ExUnit.Case, async: false

  @module_key {Otel.API.Trace.Span, :module}
  @valid_ctx Otel.API.Trace.SpanContext.new(
               0xFF000000000000000000000000000001,
               0xFF00000000000001,
               1
             )
  @invalid_ctx %Otel.API.Trace.SpanContext{}

  # Captures every dispatched call as a tagged tuple so the
  # facade tests can assert that each function routed through
  # `get_module/0` with the exact arguments it received.
  # `@behaviour Otel.API.Trace.Span` keeps the callback shape
  # in sync with the facade — a removed or renamed callback
  # surfaces here as a compile warning.
  defmodule TagModule do
    @behaviour Otel.API.Trace.Span

    @impl true
    def recording?(ctx), do: {:recording?, ctx}
    @impl true
    def set_attribute(ctx, k, v), do: {:set_attribute, ctx, k, v}
    @impl true
    def set_attributes(ctx, attrs), do: {:set_attributes, ctx, attrs}
    @impl true
    def add_event(ctx, event), do: {:add_event, ctx, event}
    @impl true
    def add_link(ctx, link), do: {:add_link, ctx, link}
    @impl true
    def set_status(ctx, status), do: {:set_status, ctx, status}
    @impl true
    def update_name(ctx, name), do: {:update_name, ctx, name}
    @impl true
    def end_span(ctx, ts), do: {:end_span, ctx, ts}
    @impl true
    def record_exception(ctx, ex, st, attrs), do: {:record_exception, ctx, ex, st, attrs}
  end

  # Reset the dispatch slot to a known empty state for every test
  # and restore whatever the application installed
  # (`Otel.SDK.Trace.Span` under normal boot) on exit. Without
  # this isolation, other async:false suites that restart `:otel`
  # could leave the slot pointing at the SDK module — and the
  # SDK's ETS-backed storage may briefly be down, causing the
  # facade tests to crash.
  setup do
    saved = :persistent_term.get(@module_key, nil)
    :persistent_term.erase(@module_key)

    on_exit(fn ->
      if saved,
        do: :persistent_term.put(@module_key, saved),
        else: :persistent_term.erase(@module_key)
    end)
  end

  describe "get_context/1 (no dispatch — pure value semantics)" do
    test "returns valid SpanContext as-is" do
      assert Otel.API.Trace.Span.get_context(@valid_ctx) == @valid_ctx
    end

    test "returns invalid SpanContext as-is" do
      assert Otel.API.Trace.Span.get_context(@invalid_ctx) == @invalid_ctx
    end
  end

  describe "Noop fallback (no module registered)" do
    # Noop's own behaviour is exhaustively verified in
    # `Otel.API.Trace.Span.NoopTest`. These tests only assert
    # that the facade reaches Noop when nothing is registered.
    test "recording?/1 returns false (Noop default)" do
      assert Otel.API.Trace.Span.recording?(@valid_ctx) == false
    end

    test "set_status/2 returns :ok (Noop default)" do
      assert Otel.API.Trace.Span.set_status(@valid_ctx, Otel.API.Trace.Status.new(:error)) == :ok
    end
  end

  describe "set_module/1 + facade dispatch" do
    setup do
      Otel.API.Trace.Span.set_module(TagModule)
      :ok
    end

    test "recording?/1" do
      assert Otel.API.Trace.Span.recording?(@valid_ctx) == {:recording?, @valid_ctx}
    end

    test "set_attribute/3" do
      assert Otel.API.Trace.Span.set_attribute(@valid_ctx, "k", "v") ==
               {:set_attribute, @valid_ctx, "k", "v"}
    end

    test "set_attributes/2" do
      attrs = %{"k" => "v"}

      assert Otel.API.Trace.Span.set_attributes(@valid_ctx, attrs) ==
               {:set_attributes, @valid_ctx, attrs}
    end

    test "add_event/2" do
      event = Otel.API.Trace.Event.new("e")
      assert Otel.API.Trace.Span.add_event(@valid_ctx, event) == {:add_event, @valid_ctx, event}
    end

    test "add_link/2" do
      link = %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(0xAA, 0xBB)}
      assert Otel.API.Trace.Span.add_link(@valid_ctx, link) == {:add_link, @valid_ctx, link}
    end

    test "set_status/2" do
      status = Otel.API.Trace.Status.new(:ok)

      assert Otel.API.Trace.Span.set_status(@valid_ctx, status) ==
               {:set_status, @valid_ctx, status}
    end

    test "update_name/2" do
      assert Otel.API.Trace.Span.update_name(@valid_ctx, "new") ==
               {:update_name, @valid_ctx, "new"}
    end

    test "end_span/1 substitutes a default timestamp" do
      assert {:end_span, @valid_ctx, ts} = Otel.API.Trace.Span.end_span(@valid_ctx)
      assert is_integer(ts) and ts > 0
    end

    test "end_span/2 forwards explicit timestamp" do
      assert Otel.API.Trace.Span.end_span(@valid_ctx, 1_000_000) ==
               {:end_span, @valid_ctx, 1_000_000}
    end

    test "record_exception/2 defaults stacktrace and attributes" do
      ex = %RuntimeError{message: "oops"}

      assert Otel.API.Trace.Span.record_exception(@valid_ctx, ex) ==
               {:record_exception, @valid_ctx, ex, [], %{}}
    end

    test "record_exception/3 forwards stacktrace, defaults attributes" do
      ex = %RuntimeError{message: "oops"}
      st = [{__MODULE__, :test, 0, []}]

      assert Otel.API.Trace.Span.record_exception(@valid_ctx, ex, st) ==
               {:record_exception, @valid_ctx, ex, st, %{}}
    end

    test "record_exception/4 forwards everything" do
      ex = %RuntimeError{message: "oops"}
      st = [{__MODULE__, :test, 0, []}]
      attrs = %{"extra" => "info"}

      assert Otel.API.Trace.Span.record_exception(@valid_ctx, ex, st, attrs) ==
               {:record_exception, @valid_ctx, ex, st, attrs}
    end
  end
end
