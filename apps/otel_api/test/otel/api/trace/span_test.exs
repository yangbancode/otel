defmodule Otel.API.Trace.SpanTest.FakeSpanOperations do
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(_span_ctx), do: true

  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: Otel.API.Attribute.key(),
          value :: Otel.API.Attribute.value()
        ) :: :ok
  def set_attribute(_span_ctx, _key, _value), do: :ok

  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: Otel.API.Attribute.attributes()
        ) :: :ok
  def set_attributes(_span_ctx, _attributes), do: :ok

  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          event :: Otel.API.Trace.Event.t()
        ) :: :ok
  def add_event(_span_ctx, _event), do: :ok

  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          link :: Otel.API.Trace.Link.t()
        ) :: :ok
  def add_link(_span_ctx, _link), do: :ok

  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          status :: Otel.API.Trace.Status.t()
        ) :: :ok
  def set_status(_span_ctx, _status), do: :ok

  @spec update_name(span_ctx :: Otel.API.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(_span_ctx, _name), do: :ok

  @spec end_span(span_ctx :: Otel.API.Trace.SpanContext.t(), timestamp :: integer() | nil) :: :ok
  def end_span(_span_ctx, _timestamp), do: :ok

  @spec record_exception(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: Otel.API.Attribute.attributes()
        ) :: :ok
  def record_exception(_span_ctx, _exception, _stacktrace, _attributes), do: :ok
end

defmodule Otel.API.Trace.SpanTest do
  use ExUnit.Case, async: false

  @valid_ctx Otel.API.Trace.SpanContext.new(
               0xFF000000000000000000000000000001,
               0xFF00000000000001,
               1
             )
  @invalid_ctx %Otel.API.Trace.SpanContext{}

  describe "get_context/1" do
    test "returns the same SpanContext" do
      assert Otel.API.Trace.Span.get_context(@valid_ctx) == @valid_ctx
    end

    test "returns invalid SpanContext as-is" do
      assert Otel.API.Trace.Span.get_context(@invalid_ctx) == @invalid_ctx
    end
  end

  describe "recording?/1" do
    test "returns false without SDK (always non-recording)" do
      assert Otel.API.Trace.Span.recording?(@valid_ctx) == false
    end

    test "returns false for invalid span" do
      assert Otel.API.Trace.Span.recording?(@invalid_ctx) == false
    end
  end

  describe "no-op operations on API level" do
    test "set_attribute returns :ok" do
      assert Otel.API.Trace.Span.set_attribute(@valid_ctx, "key", "value") == :ok
    end

    test "set_attributes with map returns :ok" do
      assert Otel.API.Trace.Span.set_attributes(@valid_ctx, %{"key" => "value"}) == :ok
    end

    test "set_attributes with multiple map entries returns :ok" do
      assert Otel.API.Trace.Span.set_attributes(@valid_ctx, %{"key" => "value", "other" => 42}) ==
               :ok
    end

    test "add_event returns :ok" do
      event = Otel.API.Trace.Event.new("event_name")
      assert Otel.API.Trace.Span.add_event(@valid_ctx, event) == :ok
    end

    test "add_event with attributes and timestamp returns :ok" do
      event = Otel.API.Trace.Event.new("event_name", %{"key" => "val"}, 1_000)
      assert Otel.API.Trace.Span.add_event(@valid_ctx, event) == :ok
    end

    test "add_link returns :ok" do
      other = Otel.API.Trace.SpanContext.new(0xAA, 0xBB)
      link = Otel.API.Trace.Link.new(other)
      assert Otel.API.Trace.Span.add_link(@valid_ctx, link) == :ok
    end

    test "add_link with attributes returns :ok" do
      other = Otel.API.Trace.SpanContext.new(0xAA, 0xBB)
      link = Otel.API.Trace.Link.new(other, %{"key" => "val"})
      assert Otel.API.Trace.Span.add_link(@valid_ctx, link) == :ok
    end

    test "set_status :ok returns :ok" do
      status = Otel.API.Trace.Status.new(:ok)
      assert Otel.API.Trace.Span.set_status(@valid_ctx, status) == :ok
    end

    test "set_status :error with description returns :ok" do
      status = Otel.API.Trace.Status.new(:error, "something failed")
      assert Otel.API.Trace.Span.set_status(@valid_ctx, status) == :ok
    end

    test "set_status :error without description returns :ok" do
      status = Otel.API.Trace.Status.new(:error)
      assert Otel.API.Trace.Span.set_status(@valid_ctx, status) == :ok
    end

    test "set_status :unset returns :ok" do
      status = Otel.API.Trace.Status.new(:unset)
      assert Otel.API.Trace.Span.set_status(@valid_ctx, status) == :ok
    end

    test "update_name returns :ok" do
      assert Otel.API.Trace.Span.update_name(@valid_ctx, "new_name") == :ok
    end

    test "end_span returns :ok" do
      assert Otel.API.Trace.Span.end_span(@valid_ctx) == :ok
    end

    test "end_span with timestamp returns :ok" do
      assert Otel.API.Trace.Span.end_span(@valid_ctx, 1_000_000) == :ok
    end

    test "record_exception returns :ok" do
      assert Otel.API.Trace.Span.record_exception(@valid_ctx, %RuntimeError{message: "oops"}) ==
               :ok
    end

    test "record_exception with stacktrace returns :ok" do
      assert Otel.API.Trace.Span.record_exception(
               @valid_ctx,
               %RuntimeError{message: "oops"},
               [{__MODULE__, :test, 0, []}]
             ) == :ok
    end

    test "record_exception with stacktrace and attributes returns :ok" do
      assert Otel.API.Trace.Span.record_exception(
               @valid_ctx,
               %RuntimeError{message: "oops"},
               [{__MODULE__, :test, 0, []}],
               %{"extra" => "info"}
             ) == :ok
    end
  end

  describe "operations on invalid span" do
    test "set_attribute on invalid span returns :ok" do
      assert Otel.API.Trace.Span.set_attribute(@invalid_ctx, "key", "value") == :ok
    end

    test "add_event on invalid span returns :ok" do
      event = Otel.API.Trace.Event.new("event")
      assert Otel.API.Trace.Span.add_event(@invalid_ctx, event) == :ok
    end

    test "set_status on invalid span returns :ok" do
      status = Otel.API.Trace.Status.new(:error, "fail")
      assert Otel.API.Trace.Span.set_status(@invalid_ctx, status) == :ok
    end

    test "end_span on invalid span returns :ok" do
      assert Otel.API.Trace.Span.end_span(@invalid_ctx) == :ok
    end

    test "record_exception on invalid span returns :ok" do
      assert Otel.API.Trace.Span.record_exception(@invalid_ctx, %RuntimeError{message: "oops"}) ==
               :ok
    end
  end

  describe "dispatch to registered module" do
    setup do
      Otel.API.Trace.Span.set_module(Otel.API.Trace.SpanTest.FakeSpanOperations)

      on_exit(fn ->
        :persistent_term.erase({Otel.API.Trace.Span, :module})
      end)

      :ok
    end

    test "get_module returns registered module" do
      assert Otel.API.Trace.Span.get_module() == Otel.API.Trace.SpanTest.FakeSpanOperations
    end

    test "recording? dispatches to module" do
      assert Otel.API.Trace.Span.recording?(@valid_ctx) == true
    end

    test "set_attribute dispatches to module" do
      assert Otel.API.Trace.Span.set_attribute(@valid_ctx, "key", "val") == :ok
    end

    test "set_attributes dispatches to module" do
      assert Otel.API.Trace.Span.set_attributes(@valid_ctx, %{"key" => "val"}) == :ok
    end

    test "add_event dispatches to module" do
      event = Otel.API.Trace.Event.new("event")
      assert Otel.API.Trace.Span.add_event(@valid_ctx, event) == :ok
    end

    test "add_link dispatches to module" do
      other = Otel.API.Trace.SpanContext.new(0xAA, 0xBB)
      link = Otel.API.Trace.Link.new(other)
      assert Otel.API.Trace.Span.add_link(@valid_ctx, link) == :ok
    end

    test "set_status dispatches to module" do
      status = Otel.API.Trace.Status.new(:error, "fail")
      assert Otel.API.Trace.Span.set_status(@valid_ctx, status) == :ok
    end

    test "update_name dispatches to module" do
      assert Otel.API.Trace.Span.update_name(@valid_ctx, "new") == :ok
    end

    test "end_span dispatches to module" do
      assert Otel.API.Trace.Span.end_span(@valid_ctx) == :ok
    end

    test "record_exception dispatches to module" do
      assert Otel.API.Trace.Span.record_exception(@valid_ctx, %RuntimeError{message: "oops"}) ==
               :ok
    end
  end
end
