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
  @spec shutdown(
          config :: Otel.SDK.Trace.SpanProcessor.config(),
          timeout :: timeout()
        ) :: :ok
  def shutdown(_config, _timeout \\ 5_000), do: :ok

  @impl true
  @spec force_flush(
          config :: Otel.SDK.Trace.SpanProcessor.config(),
          timeout :: timeout()
        ) :: :ok
  def force_flush(_config, _timeout \\ 5_000), do: :ok
end

defmodule Otel.SDK.Trace.SpanOperationsTest do
  use ExUnit.Case

  setup do
    # Ensure SDK is running for tests that don't call start_span/restart_sdk
    # (auxiliary services like SpanStorage need to be alive).
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  defp restart_sdk(env) do
    Application.stop(:otel_sdk)
    for {pillar, opts} <- env, do: Application.put_env(:otel_sdk, pillar, opts)
    Application.ensure_all_started(:otel_sdk)

    on_exit(fn ->
      Application.stop(:otel_sdk)
      for {pillar, _} <- env, do: Application.delete_env(:otel_sdk, pillar)
    end)

    :ok
  end

  defp start_span(opts \\ []) do
    processors = Keyword.get(opts, :processors, [])
    span_limits = Keyword.get(opts, :span_limits, %Otel.SDK.Trace.SpanLimits{})

    restart_sdk(trace: [processors: processors, span_limits: span_limits])

    tracer = with_processor_tracer()
    ctx = Otel.API.Ctx.new()
    Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "test_span", opts)
  end

  defp with_processor_tracer do
    {_module, tracer_config} =
      Otel.SDK.Trace.TracerProvider.get_tracer(
        Otel.SDK.Trace.TracerProvider,
        %Otel.API.InstrumentationScope{name: "test_lib"}
      )

    {Otel.SDK.Trace.Tracer, tracer_config}
  end

  describe "recording?/1" do
    test "returns true for active span" do
      span_ctx = start_span()
      assert Otel.SDK.Trace.Span.recording?(span_ctx) == true
    end

    test "returns false after end_span" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.Span.recording?(span_ctx) == false
    end

    test "returns false for unknown span_id" do
      span_ctx = %Otel.API.Trace.SpanContext{span_id: 999_999}
      assert Otel.SDK.Trace.Span.recording?(span_ctx) == false
    end
  end

  describe "set_attribute/3" do
    test "sets a single attribute" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "key", "value")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["key"] == "value"
    end

    test "overwrites existing attribute" do
      span_ctx = start_span(attributes: %{"key" => "old"})
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "key", "new")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["key"] == "new"
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.Span.set_attribute(span_ctx, "key", "value") == :ok
    end

    test "enforces attribute_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2})
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "a", 1)
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "b", 2)
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "c", 3)
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "d", 4)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert map_size(span.attributes) == 2
      assert Map.has_key?(span.attributes, "a")
      assert Map.has_key?(span.attributes, "b")
      assert span.dropped_attributes_count == 2
    end

    test "allows overwrite even when at limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 1})
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "a", 1)
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "a", 2)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["a"] == 2
      assert span.dropped_attributes_count == 0
    end

    test "truncates string value" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 5})

      Otel.SDK.Trace.Span.set_attribute(span_ctx, "key", "hello world")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["key"] == "hello"
    end

    test "does not truncate non-string values" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 1})

      Otel.SDK.Trace.Span.set_attribute(span_ctx, "num", 12_345)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["num"] == 12_345
    end

    test "truncates strings inside arrays" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3})

      Otel.SDK.Trace.Span.set_attribute(span_ctx, "tags", ["hello", "world"])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["tags"] == ["hel", "wor"]
    end

    test "infinity value length limit does not truncate" do
      span_ctx =
        start_span(
          span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: :infinity}
        )

      long_value = String.duplicate("a", 10_000)
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "key", long_value)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["key"] == long_value
    end
  end

  describe "set_attributes/2" do
    test "sets multiple attributes" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.set_attributes(span_ctx, %{"a" => 1, "b" => 2})

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["a"] == 1
      assert span.attributes["b"] == 2
    end

    test "accepts list of tuples" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.set_attributes(span_ctx, [{"a", 1}, {"b", 2}])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["a"] == 1
      assert span.attributes["b"] == 2
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.Span.set_attributes(span_ctx, %{"a" => 1}) == :ok
    end

    test "overwrites existing keys" do
      span_ctx = start_span(attributes: %{"key" => "old"})
      Otel.SDK.Trace.Span.set_attributes(span_ctx, %{"key" => "new"})

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["key"] == "new"
    end

    test "enforces attribute_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2})
      Otel.SDK.Trace.Span.set_attributes(span_ctx, %{"a" => 1, "b" => 2, "c" => 3, "d" => 4})

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert map_size(span.attributes) == 2
      assert span.dropped_attributes_count == 2
    end
  end

  describe "add_event/2" do
    test "adds an event" do
      span_ctx = start_span()
      event = Otel.API.Trace.Event.new("my_event")
      Otel.SDK.Trace.Span.add_event(span_ctx, event)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.events) == 1
      stored = hd(span.events)
      assert stored.name == "my_event"
    end

    test "adds event with attributes and custom timestamp" do
      span_ctx = start_span()
      ts = 1_000_000_000
      event = Otel.API.Trace.Event.new("event", %{"key" => "val"}, ts)
      Otel.SDK.Trace.Span.add_event(span_ctx, event)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      stored = hd(span.events)
      assert stored.timestamp == ts
      assert stored.attributes["key"] == "val"
    end

    test "preserves insertion order" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.add_event(span_ctx, Otel.API.Trace.Event.new("first"))
      Otel.SDK.Trace.Span.add_event(span_ctx, Otel.API.Trace.Event.new("second"))

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert Enum.map(span.events, & &1.name) == ["first", "second"]
    end

    test "enforces event_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{event_count_limit: 1})
      Otel.SDK.Trace.Span.add_event(span_ctx, Otel.API.Trace.Event.new("first"))
      Otel.SDK.Trace.Span.add_event(span_ctx, Otel.API.Trace.Event.new("second"))
      Otel.SDK.Trace.Span.add_event(span_ctx, Otel.API.Trace.Event.new("third"))

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.events) == 1
      assert span.dropped_events_count == 2
    end

    test "truncates event attribute values" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3})

      event = Otel.API.Trace.Event.new("event", %{"key" => "hello world"})
      Otel.SDK.Trace.Span.add_event(span_ctx, event)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      stored = hd(span.events)
      assert stored.attributes["key"] == "hel"
    end

    test "enforces attribute_per_event_limit" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_per_event_limit: 1})

      event = Otel.API.Trace.Event.new("event", %{"a" => 1, "b" => 2, "c" => 3})
      Otel.SDK.Trace.Span.add_event(span_ctx, event)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      stored = hd(span.events)
      assert %Otel.SDK.Trace.Event{} = stored
      assert map_size(stored.attributes) == 1
      assert stored.dropped_attributes_count == 2
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      Otel.SDK.Trace.Span.add_event(span_ctx, Otel.API.Trace.Event.new("event"))
      # span removed from ETS, so no way to check — just verify no crash
    end
  end

  describe "add_link/2" do
    test "adds a link after creation" do
      span_ctx = start_span()
      linked_ctx = Otel.API.Trace.SpanContext.new(100, 200)
      link = %Otel.API.Trace.Link{context: linked_ctx, attributes: %{"key" => "val"}}
      Otel.SDK.Trace.Span.add_link(span_ctx, link)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.links) == 1
      stored = hd(span.links)
      assert stored.context.trace_id == 100
      assert stored.attributes["key"] == "val"
    end

    test "enforces link_count_limit" do
      span_ctx = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{link_count_limit: 1})

      Otel.SDK.Trace.Span.add_link(
        span_ctx,
        %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(1, 1)}
      )

      Otel.SDK.Trace.Span.add_link(
        span_ctx,
        %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(2, 2)}
      )

      Otel.SDK.Trace.Span.add_link(
        span_ctx,
        %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(3, 3)}
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.links) == 1
      assert span.dropped_links_count == 2
    end

    test "tracks per-link dropped attribute count when over per-link limit" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_per_link_limit: 1})

      Otel.SDK.Trace.Span.add_link(span_ctx, %Otel.API.Trace.Link{
        context: Otel.API.Trace.SpanContext.new(1, 1),
        attributes: %{"a" => 1, "b" => 2, "c" => 3}
      })

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      [stored] = span.links
      assert %Otel.SDK.Trace.Link{} = stored
      assert map_size(stored.attributes) == 1
      assert stored.dropped_attributes_count == 2
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)

      link = %Otel.API.Trace.Link{context: Otel.API.Trace.SpanContext.new(1, 1)}
      assert Otel.SDK.Trace.Span.add_link(span_ctx, link) == :ok
    end

    test "truncates link attribute values" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3})

      link =
        %Otel.API.Trace.Link{
          context: Otel.API.Trace.SpanContext.new(1, 1),
          attributes: %{"key" => "hello world"}
        }

      Otel.SDK.Trace.Span.add_link(span_ctx, link)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      stored = hd(span.links)
      assert stored.attributes["key"] == "hel"
    end

    test "enforces attribute_per_link_limit" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_per_link_limit: 1})

      link =
        %Otel.API.Trace.Link{
          context: Otel.API.Trace.SpanContext.new(1, 1),
          attributes: %{"a" => 1, "b" => 2}
        }

      Otel.SDK.Trace.Span.add_link(span_ctx, link)

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      stored = hd(span.links)
      assert map_size(stored.attributes) == 1
    end
  end

  describe "set_status/2" do
    test "sets error status with description" do
      span_ctx = start_span()

      Otel.SDK.Trace.Span.set_status(
        span_ctx,
        Otel.API.Trace.Status.new(:error, "something failed")
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == %Otel.API.Trace.Status{code: :error, description: "something failed"}
    end

    test "sets ok status" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.set_status(span_ctx, Otel.API.Trace.Status.new(:ok))

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == %Otel.API.Trace.Status{code: :ok, description: ""}
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)

      assert Otel.SDK.Trace.Span.set_status(
               span_ctx,
               Otel.API.Trace.Status.new(:error, "fail")
             ) == :ok
    end

    test "setting unset is ignored" do
      span_ctx = start_span()

      Otel.SDK.Trace.Span.set_status(
        span_ctx,
        Otel.API.Trace.Status.new(:error, "fail")
      )

      Otel.SDK.Trace.Span.set_status(span_ctx, Otel.API.Trace.Status.new(:unset))

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == %Otel.API.Trace.Status{code: :error, description: "fail"}
    end

    test "ok is final — error after ok is ignored" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.set_status(span_ctx, Otel.API.Trace.Status.new(:ok))

      Otel.SDK.Trace.Span.set_status(
        span_ctx,
        Otel.API.Trace.Status.new(:error, "fail")
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == %Otel.API.Trace.Status{code: :ok, description: ""}
    end

    test "error overrides unset (default)" do
      span_ctx = start_span()

      Otel.SDK.Trace.Span.set_status(
        span_ctx,
        Otel.API.Trace.Status.new(:error, "fail")
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == %Otel.API.Trace.Status{code: :error, description: "fail"}
    end

    test "ok overrides error" do
      span_ctx = start_span()

      Otel.SDK.Trace.Span.set_status(
        span_ctx,
        Otel.API.Trace.Status.new(:error, "fail")
      )

      Otel.SDK.Trace.Span.set_status(span_ctx, Otel.API.Trace.Status.new(:ok))

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.status == %Otel.API.Trace.Status{code: :ok, description: ""}
    end
  end

  describe "update_name/2" do
    test "updates the span name" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.update_name(span_ctx, "new_name")

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.name == "new_name"
    end

    test "no-op on ended span" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.Span.update_name(span_ctx, "new_name") == :ok
    end
  end

  describe "end_span/2" do
    test "removes span from ETS" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
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
      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
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

      Otel.SDK.Trace.Span.end_span(span_ctx, 42)

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

      Otel.SDK.Trace.Span.end_span(span_ctx, nil)

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

      Otel.SDK.Trace.Span.end_span(span_ctx, nil)

      assert_receive {:on_end, _}
      assert_receive {:on_end, _}
    end

    test "second end_span is no-op" do
      span_ctx = start_span()
      assert Otel.SDK.Trace.Span.end_span(span_ctx, nil) == :ok
      assert Otel.SDK.Trace.Span.end_span(span_ctx, nil) == :ok
    end

    test "logs span limits applied warning when any drop occurred (spec L873-L876)" do
      span_ctx =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 1})

      Otel.SDK.Trace.Span.set_attribute(span_ctx, "a", 1)
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "b", 2)
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "c", 3)

      log = ExUnit.CaptureLog.capture_log(fn -> Otel.SDK.Trace.Span.end_span(span_ctx, nil) end)

      assert log =~ "span limits applied"
      assert log =~ "dropped 2 attributes"
    end

    test "no warning when no limits triggered" do
      span_ctx = start_span()
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "a", 1)

      log = ExUnit.CaptureLog.capture_log(fn -> Otel.SDK.Trace.Span.end_span(span_ctx, nil) end)

      refute log =~ "span limits applied"
    end
  end

  describe "record_exception/4" do
    test "adds exception event" do
      span_ctx = start_span()

      Otel.SDK.Trace.Span.record_exception(
        span_ctx,
        %RuntimeError{message: "boom"},
        [],
        %{}
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert length(span.events) == 1
      event = hd(span.events)
      assert event.name == "exception"
      assert event.attributes["exception.type"] == "RuntimeError"
      assert event.attributes["exception.message"] == "boom"
    end

    test "includes stacktrace" do
      span_ctx = start_span()
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.exs", line: 1]}]

      Otel.SDK.Trace.Span.record_exception(
        span_ctx,
        %RuntimeError{message: "boom"},
        stacktrace,
        %{}
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      event = hd(span.events)
      assert is_binary(event.attributes["exception.stacktrace"])
    end

    test "merges additional attributes" do
      span_ctx = start_span()

      Otel.SDK.Trace.Span.record_exception(
        span_ctx,
        %RuntimeError{message: "boom"},
        [],
        %{"custom" => "value"}
      )

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      event = hd(span.events)
      assert event.attributes["exception.type"] == "RuntimeError"
      assert event.attributes["custom"] == "value"
    end
  end

  describe "API dispatch" do
    test "Otel.API.Trace.Span dispatches to SDK" do
      span_ctx = start_span()

      Otel.API.Trace.Span.set_attribute(span_ctx, "api_key", "api_val")
      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.attributes["api_key"] == "api_val"

      assert Otel.API.Trace.Span.recording?(span_ctx) == true

      Otel.API.Trace.Span.end_span(span_ctx)
      assert Otel.API.Trace.Span.recording?(span_ctx) == false
    end

    test "with_span ends span and calls processors" do
      restart_sdk(
        trace: [
          processors: [{Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}]
        ]
      )

      tracer = with_processor_tracer()

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
      restart_sdk(
        trace: [
          processors: [{Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}]
        ]
      )

      tracer = with_processor_tracer()

      assert_raise RuntimeError, "boom", fn ->
        Otel.API.Trace.with_span(tracer, "error_span", [], fn _span_ctx ->
          raise "boom"
        end)
      end

      assert_receive {:on_end, ended_span}
      # Status description is the raw exception message per spec
      # (trace/exceptions.md L35: `e.getMessage()`), not the formatted
      # "** (RuntimeError) boom" Elixir rendering.
      assert %Otel.API.Trace.Status{code: :error, description: "boom"} = ended_span.status
      assert length(ended_span.events) == 1
      event = hd(ended_span.events)
      assert event.name == "exception"
      assert event.attributes["exception.message"] == "boom"
      assert event.attributes["exception.type"] == "RuntimeError"
    end

    test "with_span normalizes non-exception raise to ErlangError" do
      restart_sdk(
        trace: [
          processors: [{Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}]
        ]
      )

      tracer = with_processor_tracer()

      assert_raise ErlangError, fn ->
        Otel.API.Trace.with_span(tracer, "error_span", [], fn _span_ctx ->
          :erlang.error(:some_atom_reason)
        end)
      end

      assert_receive {:on_end, ended_span}
      assert %Otel.API.Trace.Status{code: :error} = ended_span.status
      # Description must be a human-readable message, not the raw atom
      assert is_binary(ended_span.status.description)
    end

    test "with_span records :throw with formatted description" do
      restart_sdk(
        trace: [
          processors: [{Otel.SDK.Trace.SpanOperationsTest.TestProcessor, %{test_pid: self()}}]
        ]
      )

      tracer = with_processor_tracer()

      catch_throw(
        Otel.API.Trace.with_span(tracer, "throw_span", [], fn _span_ctx ->
          throw(:something)
        end)
      )

      assert_receive {:on_end, ended_span}
      assert %Otel.API.Trace.Status{code: :error} = ended_span.status
      assert is_binary(ended_span.status.description)
    end
  end
end
