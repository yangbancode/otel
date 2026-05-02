defmodule Otel.Trace.Span.NoopTest do
  use ExUnit.Case, async: true

  # Spec trace/api.md L862-L863 — Noop Span operations have no side
  # effects. `recording?/1` is always `false`; every other callback
  # returns `:ok` regardless of input.

  @valid_ctx Otel.Trace.SpanContext.new(
               0xFF000000000000000000000000000001,
               0xFF00000000000001,
               1
             )

  describe "recording?/1" do
    test "always false (a Noop span is non-recording by definition)" do
      refute Otel.Trace.Span.Noop.recording?(@valid_ctx)
      refute Otel.Trace.Span.Noop.recording?(%Otel.Trace.SpanContext{})
    end
  end

  describe "side-effect callbacks always return :ok" do
    test "set_attribute/3 across primitive value shapes" do
      assert :ok = Otel.Trace.Span.Noop.set_attribute(@valid_ctx, "k", "string")
      assert :ok = Otel.Trace.Span.Noop.set_attribute(@valid_ctx, "k", 42)
      assert :ok = Otel.Trace.Span.Noop.set_attribute(@valid_ctx, "k", true)
      assert :ok = Otel.Trace.Span.Noop.set_attribute(@valid_ctx, "k", [1, 2, 3])
    end

    test "set_attributes/2 with empty and non-empty maps" do
      assert :ok = Otel.Trace.Span.Noop.set_attributes(@valid_ctx, %{})
      assert :ok = Otel.Trace.Span.Noop.set_attributes(@valid_ctx, %{"k" => "v"})
    end

    test "add_event/2 with and without attributes" do
      assert :ok = Otel.Trace.Span.Noop.add_event(@valid_ctx, Otel.Trace.Event.new("e"))

      assert :ok =
               Otel.Trace.Span.Noop.add_event(
                 @valid_ctx,
                 Otel.Trace.Event.new("e", %{"k" => "v"})
               )
    end

    test "add_link/2" do
      link = %Otel.Trace.Link{context: Otel.Trace.SpanContext.new(0xAA, 0xBB)}
      assert :ok = Otel.Trace.Span.Noop.add_link(@valid_ctx, link)
    end

    test "set_status/2 across all codes" do
      assert :ok =
               Otel.Trace.Span.Noop.set_status(@valid_ctx, Otel.Trace.Status.new(:ok))

      assert :ok =
               Otel.Trace.Span.Noop.set_status(@valid_ctx, Otel.Trace.Status.new(:unset))

      assert :ok =
               Otel.Trace.Span.Noop.set_status(
                 @valid_ctx,
                 Otel.Trace.Status.new(:error, "boom")
               )
    end

    test "update_name/2" do
      assert :ok = Otel.Trace.Span.Noop.update_name(@valid_ctx, "new_name")
    end

    test "end_span/2 with explicit timestamp" do
      assert :ok = Otel.Trace.Span.Noop.end_span(@valid_ctx, 1_000_000)
    end

    test "record_exception/4 with and without stacktrace + extras" do
      ex = %RuntimeError{message: "oops"}
      assert :ok = Otel.Trace.Span.Noop.record_exception(@valid_ctx, ex, [], %{})

      assert :ok =
               Otel.Trace.Span.Noop.record_exception(
                 @valid_ctx,
                 ex,
                 [{__MODULE__, :test, 0, []}],
                 %{"extra" => "info"}
               )
    end
  end
end
