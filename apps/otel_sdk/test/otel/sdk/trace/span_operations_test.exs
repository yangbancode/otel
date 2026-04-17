defmodule Otel.SDK.Trace.SpanOperationsTest.TestProcessor do
  @behaviour Otel.SDK.Trace.SpanProcessor

  @impl true
  @spec on_start(
          ctx :: Otel.API.Ctx.t(),
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: Otel.SDK.Trace.Span.t()
  def on_start(_ctx, span, _config), do: span

  @impl true
  @spec on_end(
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: :ok
  def on_end(span, %{test_pid: pid}) do
    send(pid, {:on_end, span})
    :ok
  end

  @impl true
  @spec shutdown(config :: Otel.SDK.Trace.SpanProcessor.config()) :: :ok
  def shutdown(_config), do: :ok

  @impl true
  @spec force_flush(config :: Otel.SDK.Trace.SpanProcessor.config()) :: :ok
  def force_flush(_config), do: :ok
end

defmodule Otel.SDK.Trace.SpanOperationsTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  defp attr(k, v) when is_binary(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.string(v))
  end

  defp attr(k, v) when is_integer(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.int(v))
  end

  defp attrs_map(map) do
    Enum.map(map, fn {k, v} -> attr(k, v) end)
  end

  defp find_attr_value(attributes, key) do
    case Enum.find(attributes, &(&1.key == key)) do
      nil -> nil
      %Otel.API.Common.Attribute{value: value} -> value.value
    end
  end

  defp start_span(opts \\ []) do
    processors = Keyword.get(opts, :processors, [])
    span_limits = Keyword.get(opts, :span_limits, %Otel.SDK.Trace.SpanLimits{})

    {:ok, provider} =
      Otel.SDK.Trace.TracerProvider.start_link(
        config: %{processors: processors, span_limits: span_limits}
      )

    {_module, tracer_config} =
      Otel.SDK.Trace.TracerProvider.get_tracer(provider, "test_lib")

    tracer = {Otel.SDK.Trace.Tracer, tracer_config}
    ctx = Otel.API.Ctx.new()
    span_ctx = Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "test_span", opts)
    span_ctx
  end

  describe "recording?/1" do
    test "returns true for active span" do
      span_ctx = start_span()
      assert Otel.SDK.Trace.SpanOperations.recording?(span_ctx) == true
    end

    test "returns false after end_span" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.SpanOperations.recording?(span_ctx) == false
    end

    test "returns false for unknown span_id" do
      span_ctx = %Otel.API.Trace.SpanContext{
        span_id: Otel.API.Trace.SpanId.new(<<999_999::64>>)
      }

      assert Otel.SDK.Trace.SpanOperations.recording?(span_ctx) == false
    end
  end

  describe "set_attribute/3" do
    test "sets a single attribute" do
      span_ctx = start_span()

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "key",
        Otel.API.Common.AnyValue.string("value")
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "key") == "value"
    end

    test "overwrites existing attribute" do
      span_ctx = start_span(attributes: [attr("key", "old")])

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "key",
        Otel.API.Common.AnyValue.string("new")
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "key") == "new"
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)

      assert Otel.SDK.Trace.SpanOperations.set_attribute(
               span_ctx,
               "key",
               Otel.API.Common.AnyValue.string("value")
             ) == :ok
    end

    test "enforces attribute_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2})

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "a",
        Otel.API.Common.AnyValue.int(1)
      )

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "b",
        Otel.API.Common.AnyValue.int(2)
      )

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "c",
        Otel.API.Common.AnyValue.int(3)
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.attributes) == 2
      assert Enum.any?(span.attributes, &(&1.key == "a"))
      assert Enum.any?(span.attributes, &(&1.key == "b"))
    end

    test "allows overwrite even when at limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 1})

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "a",
        Otel.API.Common.AnyValue.int(1)
      )

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "a",
        Otel.API.Common.AnyValue.int(2)
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "a") == 2
    end

    test "truncates string value" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 5})

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "key",
        Otel.API.Common.AnyValue.string("hello world")
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "key") == "hello"
    end

    test "does not truncate non-string values" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 1})

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "num",
        Otel.API.Common.AnyValue.int(12_345)
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "num") == 12_345
    end

    test "truncates strings inside arrays" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3})

      array =
        Otel.API.Common.AnyValue.array([
          Otel.API.Common.AnyValue.string("hello"),
          Otel.API.Common.AnyValue.string("world")
        ])

      Otel.SDK.Trace.SpanOperations.set_attribute(span_ctx, "tags", array)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      value = Enum.find(span.attributes, &(&1.key == "tags")).value
      assert Enum.map(value.value, & &1.value) == ["hel", "wor"]
    end

    test "infinity value length limit does not truncate" do
      span_ctx =
        start_span(
          span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: :infinity}
        )

      long_value = String.duplicate("a", 10_000)

      Otel.SDK.Trace.SpanOperations.set_attribute(
        span_ctx,
        "key",
        Otel.API.Common.AnyValue.string(long_value)
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "key") == long_value
    end
  end

  describe "set_attributes/2" do
    test "sets multiple attributes" do
      span_ctx = start_span()

      Otel.SDK.Trace.SpanOperations.set_attributes(span_ctx, [attr("a", 1), attr("b", 2)])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "a") == 1
      assert find_attr_value(span.attributes, "b") == 2
    end

    test "accepts list of Attribute structs" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.set_attributes(span_ctx, [attr("a", 1), attr("b", 2)])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "a") == 1
      assert find_attr_value(span.attributes, "b") == 2
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.SpanOperations.set_attributes(span_ctx, [attr("a", 1)]) == :ok
    end

    test "overwrites existing keys" do
      span_ctx = start_span(attributes: [attr("key", "old")])
      Otel.SDK.Trace.SpanOperations.set_attributes(span_ctx, [attr("key", "new")])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "key") == "new"
    end

    test "enforces attribute_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2})

      Otel.SDK.Trace.SpanOperations.set_attributes(
        span_ctx,
        [attr("a", 1), attr("b", 2), attr("c", 3)]
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.attributes) <= 2
    end
  end

  describe "add_event/3" do
    test "adds an event" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "my_event", [])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.events) == 1
      assert hd(span.events).name == "my_event"
    end

    test "adds event with attributes and custom time" do
      span_ctx = start_span()
      ts = 1_000_000_000

      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "event",
        time: ts,
        attributes: [attr("key", "val")]
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      event = hd(span.events)
      assert event.time == ts
      assert find_attr_value(event.attributes, "key") == "val"
    end

    test "preserves insertion order" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "first", [])
      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "second", [])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert Enum.map(span.events, & &1.name) == ["first", "second"]
    end

    test "enforces event_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{event_count_limit: 1})
      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "first", [])
      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "second", [])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.events) == 1
    end

    test "truncates event attribute values" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3})

      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "event",
        attributes: [attr("key", "hello world")]
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      event = hd(span.events)
      assert find_attr_value(event.attributes, "key") == "hel"
    end

    test "enforces attribute_per_event_limit" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_per_event_limit: 1})

      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "event",
        attributes: attrs_map(%{"a" => 1, "b" => 2, "c" => 3})
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      event = hd(span.events)
      assert length(event.attributes) == 1
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)
      Otel.SDK.Trace.SpanOperations.add_event(span_ctx, "event", [])
      # span removed from ETS, so no way to check — just verify no crash
    end
  end

  describe "add_link/3" do
    test "adds a link after creation" do
      span_ctx = start_span()

      linked =
        Otel.API.Trace.SpanContext.new(
          Otel.API.Trace.TraceId.new(<<100::128>>),
          Otel.API.Trace.SpanId.new(<<200::64>>)
        )

      Otel.SDK.Trace.SpanOperations.add_link(span_ctx, linked, [attr("key", "val")])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.links) == 1
      {link_ctx, link_attrs} = hd(span.links)
      assert link_ctx.trace_id == Otel.API.Trace.TraceId.new(<<100::128>>)
      assert find_attr_value(link_attrs, "key") == "val"
    end

    test "enforces link_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{link_count_limit: 1})

      Otel.SDK.Trace.SpanOperations.add_link(
        span_ctx,
        Otel.API.Trace.SpanContext.new(
          Otel.API.Trace.TraceId.new(<<1::128>>),
          Otel.API.Trace.SpanId.new(<<1::64>>)
        ),
        []
      )

      Otel.SDK.Trace.SpanOperations.add_link(
        span_ctx,
        Otel.API.Trace.SpanContext.new(
          Otel.API.Trace.TraceId.new(<<2::128>>),
          Otel.API.Trace.SpanId.new(<<2::64>>)
        ),
        []
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.links) == 1
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)

      assert Otel.SDK.Trace.SpanOperations.add_link(
               span_ctx,
               Otel.API.Trace.SpanContext.new(
                 Otel.API.Trace.TraceId.new(<<1::128>>),
                 Otel.API.Trace.SpanId.new(<<1::64>>)
               ),
               []
             ) == :ok
    end

    test "truncates link attribute values" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3})

      Otel.SDK.Trace.SpanOperations.add_link(
        span_ctx,
        Otel.API.Trace.SpanContext.new(
          Otel.API.Trace.TraceId.new(<<1::128>>),
          Otel.API.Trace.SpanId.new(<<1::64>>)
        ),
        [attr("key", "hello world")]
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      {_ctx, attrs} = hd(span.links)
      assert find_attr_value(attrs, "key") == "hel"
    end

    test "enforces attribute_per_link_limit" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_per_link_limit: 1})

      Otel.SDK.Trace.SpanOperations.add_link(
        span_ctx,
        Otel.API.Trace.SpanContext.new(
          Otel.API.Trace.TraceId.new(<<1::128>>),
          Otel.API.Trace.SpanId.new(<<1::64>>)
        ),
        [attr("a", 1), attr("b", 2)]
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      {_ctx, attrs} = hd(span.links)
      assert length(attrs) == 1
    end
  end

  describe "set_status/3" do
    test "sets error status with description" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :error, "something failed")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == {:error, "something failed"}
    end

    test "sets ok status" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :ok, "")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == {:ok, ""}
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :error, "fail") == :ok
    end

    test "setting unset is ignored" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :error, "fail")
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :unset, "")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == {:error, "fail"}
    end

    test "ok is final — error after ok is ignored" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :ok, "")
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :error, "fail")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == {:ok, ""}
    end

    test "error overrides unset (default)" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :error, "fail")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == {:error, "fail"}
    end

    test "ok overrides error" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :error, "fail")
      Otel.SDK.Trace.SpanOperations.set_status(span_ctx, :ok, "")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == {:ok, ""}
    end
  end

  describe "update_name/2" do
    test "updates the span name" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.update_name(span_ctx, "new_name")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.name == "new_name"
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.SpanOperations.update_name(span_ctx, "new_name") == :ok
    end
  end

  describe "end_span/2" do
    test "removes span from ETS" do
      span_ctx = start_span()
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id) == nil
    end

    test "sets end_time" do
      span_ctx =
        start_span(
          processors: [
            {Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}
          ]
        )

      before = System.system_time(:nanosecond)
      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)
      after_time = System.system_time(:nanosecond)

      assert_receive {:on_end, ended_span}
      assert ended_span.end_time >= before
      assert ended_span.end_time <= after_time
    end

    test "uses custom timestamp" do
      span_ctx =
        start_span(
          processors: [
            {Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}
          ]
        )

      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, 42)

      assert_receive {:on_end, ended_span}
      assert ended_span.end_time == 42
    end

    test "sets is_recording to false on ended span" do
      span_ctx =
        start_span(
          processors: [
            {Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}
          ]
        )

      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)

      assert_receive {:on_end, ended_span}
      assert ended_span.is_recording == false
    end

    test "calls on_end on all processors" do
      span_ctx =
        start_span(
          processors: [
            {Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}},
            {Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}
          ]
        )

      Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil)

      assert_receive {:on_end, _}
      assert_receive {:on_end, _}
    end

    test "second end_span is no-op" do
      span_ctx = start_span()
      assert Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil) == :ok
      assert Otel.SDK.Trace.SpanOperations.end_span(span_ctx, nil) == :ok
    end
  end

  describe "record_exception/4" do
    test "adds exception event" do
      span_ctx = start_span()

      Otel.SDK.Trace.SpanOperations.record_exception(
        span_ctx,
        %RuntimeError{message: "boom"},
        [],
        []
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.events) == 1
      event = hd(span.events)
      assert event.name == "exception"
      assert find_attr_value(event.attributes, "exception.type") == "RuntimeError"
      assert find_attr_value(event.attributes, "exception.message") == "boom"
    end

    test "includes stacktrace" do
      span_ctx = start_span()
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.exs", line: 1]}]

      Otel.SDK.Trace.SpanOperations.record_exception(
        span_ctx,
        %RuntimeError{message: "boom"},
        stacktrace,
        []
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      event = hd(span.events)
      assert is_binary(find_attr_value(event.attributes, "exception.stacktrace"))
    end

    test "merges additional attributes" do
      span_ctx = start_span()

      Otel.SDK.Trace.SpanOperations.record_exception(
        span_ctx,
        %RuntimeError{message: "boom"},
        [],
        [attr("custom", "value")]
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      event = hd(span.events)
      assert find_attr_value(event.attributes, "exception.type") == "RuntimeError"
      assert find_attr_value(event.attributes, "custom") == "value"
    end
  end

  describe "API dispatch" do
    test "Otel.API.Trace.Span dispatches to SDK" do
      span_ctx = start_span()

      Otel.API.Trace.Span.set_attribute(
        span_ctx,
        "api_key",
        Otel.API.Common.AnyValue.string("api_val")
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert find_attr_value(span.attributes, "api_key") == "api_val"

      assert Otel.API.Trace.Span.recording?(span_ctx) == true

      Otel.API.Trace.Span.end_span(span_ctx)
      assert Otel.API.Trace.Span.recording?(span_ctx) == false
    end

    test "with_span ends span and calls processors" do
      {:ok, provider} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}
            ]
          }
        )

      {_module, tracer_config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(provider, "test_lib")

      tracer = {Otel.SDK.Trace.Tracer, tracer_config}

      result =
        Otel.API.Trace.with_span(tracer, "with_span_test", [], fn _span_ctx ->
          :my_result
        end)

      assert result == :my_result
      assert_receive {:on_end, ended_span}
      assert ended_span.name == "with_span_test"
      assert ended_span.is_recording == false
      assert ended_span.end_time != nil
    end

    test "with_span records exception on error" do
      {:ok, provider} =
        Otel.SDK.Trace.TracerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}
            ]
          }
        )

      {_module, tracer_config} =
        Otel.SDK.Trace.TracerProvider.get_tracer(provider, "test_lib")

      tracer = {Otel.SDK.Trace.Tracer, tracer_config}

      assert_raise RuntimeError, "boom", fn ->
        Otel.API.Trace.with_span(tracer, "error_span", [], fn _span_ctx ->
          raise "boom"
        end)
      end

      assert_receive {:on_end, ended_span}
      assert {:error, _description} = ended_span.status
      assert length(ended_span.events) == 1
      event = hd(ended_span.events)
      assert event.name == "exception"
    end
  end
end
