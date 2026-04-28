defmodule Otel.SDK.Trace.SpanOperationsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule TestProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Trace.SpanProcessor

    @impl true
    def on_start(_ctx, span, _config), do: span

    @impl true
    def on_end(span, %{test_pid: pid}) do
      send(pid, {:on_end, span})
      :ok
    end

    @impl true
    def shutdown(_config, _timeout \\ 5_000), do: :ok

    @impl true
    def force_flush(_config, _timeout \\ 5_000), do: :ok
  end

  setup do
    Application.ensure_all_started(:otel)
    :ok
  end

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)
  end

  defp tracer_for(scope_name \\ "test_lib") do
    {_, config} =
      Otel.SDK.Trace.TracerProvider.get_tracer(
        Otel.SDK.Trace.TracerProvider,
        %Otel.API.InstrumentationScope{name: scope_name}
      )

    {Otel.SDK.Trace.Tracer, config}
  end

  defp start_span(opts \\ []) do
    processors = Keyword.get(opts, :processors, [])
    span_limits = Keyword.get(opts, :span_limits, %Otel.SDK.Trace.SpanLimits{})
    restart_sdk(trace: [processors: processors, span_limits: span_limits])

    Otel.SDK.Trace.Tracer.start_span(Otel.API.Ctx.new(), tracer_for(), "test_span", opts)
  end

  defp stored(span_ctx), do: Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)

  describe "recording?/1" do
    test "true while alive; false after end_span; false for unknown span_id" do
      span_ctx = start_span()
      assert Otel.SDK.Trace.Span.recording?(span_ctx) == true

      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      assert Otel.SDK.Trace.Span.recording?(span_ctx) == false

      assert Otel.SDK.Trace.Span.recording?(%Otel.API.Trace.SpanContext{span_id: 999_999}) ==
               false
    end
  end

  describe "set_attribute/3 + set_attributes/2" do
    test "set / overwrite / no-op-after-end / count_limit / overwrite-at-limit" do
      span_ctx = start_span(attributes: %{"key" => "old"})

      Otel.SDK.Trace.Span.set_attribute(span_ctx, "key", "new")
      Otel.SDK.Trace.Span.set_attribute(span_ctx, "extra", 1)
      assert stored(span_ctx).attributes == %{"key" => "new", "extra" => 1}

      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      assert :ok = Otel.SDK.Trace.Span.set_attribute(span_ctx, "k", "v")

      capped = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2})

      for {k, v} <- [{"a", 1}, {"b", 2}, {"c", 3}, {"d", 4}],
          do: Otel.SDK.Trace.Span.set_attribute(capped, k, v)

      span = stored(capped)
      assert map_size(span.attributes) == 2
      assert span.dropped_attributes_count == 2

      one_slot = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 1})
      Otel.SDK.Trace.Span.set_attribute(one_slot, "a", 1)
      Otel.SDK.Trace.Span.set_attribute(one_slot, "a", 2)
      assert stored(one_slot).attributes["a"] == 2
      assert stored(one_slot).dropped_attributes_count == 0
    end

    test "value-length limit truncates strings (incl. inside arrays); non-strings unchanged; :infinity skips" do
      strict =
        start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 5})

      Otel.SDK.Trace.Span.set_attribute(strict, "key", "hello world")
      assert stored(strict).attributes["key"] == "hello"

      arr = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 3})
      Otel.SDK.Trace.Span.set_attribute(arr, "tags", ["hello", "world"])
      assert stored(arr).attributes["tags"] == ["hel", "wor"]

      tight = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: 1})
      Otel.SDK.Trace.Span.set_attribute(tight, "num", 12_345)
      assert stored(tight).attributes["num"] == 12_345

      infinite =
        start_span(
          span_limits: %Otel.SDK.Trace.SpanLimits{attribute_value_length_limit: :infinity}
        )

      long = String.duplicate("a", 10_000)
      Otel.SDK.Trace.Span.set_attribute(infinite, "key", long)
      assert stored(infinite).attributes["key"] == long
    end

    test "set_attributes/2 — accepts map and keyword list; honours count_limit; no-op after end" do
      span_ctx = start_span(attributes: %{"key" => "old"})
      Otel.SDK.Trace.Span.set_attributes(span_ctx, %{"a" => 1, "b" => 2, "key" => "new"})
      assert stored(span_ctx).attributes == %{"a" => 1, "b" => 2, "key" => "new"}

      kw_span = start_span()
      Otel.SDK.Trace.Span.set_attributes(kw_span, [{"a", 1}, {"b", 2}])
      assert stored(kw_span).attributes == %{"a" => 1, "b" => 2}

      capped = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 2})
      Otel.SDK.Trace.Span.set_attributes(capped, %{"a" => 1, "b" => 2, "c" => 3, "d" => 4})
      assert map_size(stored(capped).attributes) == 2
      assert stored(capped).dropped_attributes_count == 2

      Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      assert :ok = Otel.SDK.Trace.Span.set_attributes(span_ctx, %{"k" => "v"})
    end
  end

  describe "add_event/2" do
    test "appends events in insertion order; preserves attributes + custom timestamp" do
      span_ctx = start_span()

      Otel.SDK.Trace.Span.add_event(span_ctx, Otel.API.Trace.Event.new("first"))

      Otel.SDK.Trace.Span.add_event(
        span_ctx,
        Otel.API.Trace.Event.new("second", %{"key" => "val"}, 1_000_000_000)
      )

      events = stored(span_ctx).events
      assert Enum.map(events, & &1.name) == ["first", "second"]

      [_, ev2] = events
      assert ev2.timestamp == 1_000_000_000
      assert ev2.attributes["key"] == "val"
    end

    test "event_count_limit + attribute_per_event_limit + per-event value-length truncation" do
      capped =
        start_span(
          span_limits: %Otel.SDK.Trace.SpanLimits{
            event_count_limit: 1,
            attribute_per_event_limit: 1,
            attribute_value_length_limit: 3
          }
        )

      Otel.SDK.Trace.Span.add_event(
        capped,
        Otel.API.Trace.Event.new("first", %{"a" => 1, "b" => 2, "key" => "hello world"})
      )

      Otel.SDK.Trace.Span.add_event(capped, Otel.API.Trace.Event.new("dropped"))

      span = stored(capped)
      [first] = span.events
      assert first.name == "first"
      assert span.dropped_events_count == 1
      assert map_size(first.attributes) == 1
      assert first.dropped_attributes_count == 2

      first.attributes
      |> Map.values()
      |> Enum.each(fn v -> if is_binary(v), do: assert(String.length(v) <= 3) end)

      ended = start_span()
      Otel.SDK.Trace.Span.end_span(ended, nil)
      assert :ok = Otel.SDK.Trace.Span.add_event(ended, Otel.API.Trace.Event.new("late"))
    end
  end

  describe "add_link/2" do
    test "stores link with attributes; honours link_count + attribute_per_link + value-length limits" do
      span_ctx = start_span()
      linked = Otel.API.Trace.SpanContext.new(100, 200)

      Otel.SDK.Trace.Span.add_link(span_ctx, %Otel.API.Trace.Link{
        context: linked,
        attributes: %{"key" => "val"}
      })

      [stored_link] = stored(span_ctx).links
      assert stored_link.context.trace_id == 100
      assert stored_link.attributes["key"] == "val"

      capped =
        start_span(
          span_limits: %Otel.SDK.Trace.SpanLimits{
            link_count_limit: 1,
            attribute_per_link_limit: 1,
            attribute_value_length_limit: 3
          }
        )

      for {trace_id, attrs} <- [
            {1, %{"a" => 1, "b" => 2, "key" => "hello world"}},
            {2, %{}}
          ] do
        Otel.SDK.Trace.Span.add_link(
          capped,
          %Otel.API.Trace.Link{
            context: Otel.API.Trace.SpanContext.new(trace_id, trace_id),
            attributes: attrs
          }
        )
      end

      span = stored(capped)
      assert length(span.links) == 1
      assert span.dropped_links_count == 1
      [stored] = span.links
      assert map_size(stored.attributes) == 1
      assert stored.dropped_attributes_count == 2

      stored.attributes
      |> Map.values()
      |> Enum.each(fn v -> if is_binary(v), do: assert(String.length(v) <= 3) end)

      ended = start_span()
      Otel.SDK.Trace.Span.end_span(ended, nil)

      assert :ok =
               Otel.SDK.Trace.Span.add_link(ended, %Otel.API.Trace.Link{
                 context: Otel.API.Trace.SpanContext.new(1, 1)
               })
    end
  end

  # Spec trace/api.md §SetStatus L590-L620 — Ok > Error > Unset.
  # `:unset` is ignored; once Ok is set, further mutations are
  # ignored; Error overrides Unset; Ok overrides Error.
  test "set_status/2 follows Ok > Error > Unset precedence" do
    error_then_unset = start_span()
    Otel.SDK.Trace.Span.set_status(error_then_unset, Otel.API.Trace.Status.new(:error, "fail"))
    Otel.SDK.Trace.Span.set_status(error_then_unset, Otel.API.Trace.Status.new(:unset))

    assert stored(error_then_unset).status ==
             %Otel.API.Trace.Status{code: :error, description: "fail"}

    ok_then_error = start_span()
    Otel.SDK.Trace.Span.set_status(ok_then_error, Otel.API.Trace.Status.new(:ok))
    Otel.SDK.Trace.Span.set_status(ok_then_error, Otel.API.Trace.Status.new(:error, "fail"))

    assert stored(ok_then_error).status == %Otel.API.Trace.Status{code: :ok, description: ""}

    error_then_ok = start_span()
    Otel.SDK.Trace.Span.set_status(error_then_ok, Otel.API.Trace.Status.new(:error, "fail"))
    Otel.SDK.Trace.Span.set_status(error_then_ok, Otel.API.Trace.Status.new(:ok))

    assert stored(error_then_ok).status == %Otel.API.Trace.Status{code: :ok, description: ""}

    ended = start_span()
    Otel.SDK.Trace.Span.end_span(ended, nil)

    assert :ok =
             Otel.SDK.Trace.Span.set_status(ended, Otel.API.Trace.Status.new(:error, "late"))
  end

  test "update_name/2 mutates while alive; no-op after end" do
    span_ctx = start_span()
    Otel.SDK.Trace.Span.update_name(span_ctx, "new_name")
    assert stored(span_ctx).name == "new_name"

    Otel.SDK.Trace.Span.end_span(span_ctx, nil)
    assert :ok = Otel.SDK.Trace.Span.update_name(span_ctx, "ignored")
  end

  describe "end_span/2" do
    test "removes span from ETS; sets is_recording=false; uses given timestamp; calls every processor; second end is a no-op" do
      span_ctx =
        start_span(
          processors: [{TestProcessor, %{test_pid: self()}}, {TestProcessor, %{test_pid: self()}}]
        )

      :ok = Otel.SDK.Trace.Span.end_span(span_ctx, 42)
      assert_receive {:on_end, ended1}
      assert_receive {:on_end, ended2}

      assert ended1.end_time == 42
      assert ended1.is_recording == false
      assert ended2.end_time == 42
      assert Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id) == nil
      assert :ok = Otel.SDK.Trace.Span.end_span(span_ctx, nil)
    end

    test "end_span(_, nil) records System.system_time(:nanosecond)" do
      span_ctx = start_span(processors: [{TestProcessor, %{test_pid: self()}}])
      before = System.system_time(:nanosecond)
      :ok = Otel.SDK.Trace.Span.end_span(span_ctx, nil)
      after_time = System.system_time(:nanosecond)

      assert_receive {:on_end, ended}
      assert ended.end_time in before..after_time
    end

    test "logs \"span limits applied\" on end when any limit triggered; silent otherwise" do
      capped = start_span(span_limits: %Otel.SDK.Trace.SpanLimits{attribute_count_limit: 1})

      for {k, v} <- [{"a", 1}, {"b", 2}, {"c", 3}],
          do: Otel.SDK.Trace.Span.set_attribute(capped, k, v)

      log = capture_log(fn -> Otel.SDK.Trace.Span.end_span(capped, nil) end)
      assert log =~ "span limits applied"
      assert log =~ "dropped 2 attributes"

      clean = start_span()
      Otel.SDK.Trace.Span.set_attribute(clean, "a", 1)
      log = capture_log(fn -> Otel.SDK.Trace.Span.end_span(clean, nil) end)
      refute log =~ "span limits applied"
    end
  end

  test "record_exception/4 — adds 'exception' event with type/message/stacktrace + extra attrs" do
    span_ctx = start_span()
    stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.exs", line: 1]}]

    Otel.SDK.Trace.Span.record_exception(
      span_ctx,
      %RuntimeError{message: "boom"},
      stacktrace,
      %{"custom" => "value"}
    )

    [event] = stored(span_ctx).events
    assert event.name == "exception"
    assert event.attributes["exception.type"] == "RuntimeError"
    assert event.attributes["exception.message"] == "boom"
    assert is_binary(event.attributes["exception.stacktrace"])
    assert event.attributes["custom"] == "value"
  end

  describe "API dispatch (Otel.API.Trace.Span / with_span)" do
    test "API.Span dispatches into SDK.Span; recording? + set_attribute + end_span round-trip" do
      span_ctx = start_span()

      Otel.API.Trace.Span.set_attribute(span_ctx, "api_key", "api_val")
      assert stored(span_ctx).attributes["api_key"] == "api_val"

      assert Otel.API.Trace.Span.recording?(span_ctx) == true
      Otel.API.Trace.Span.end_span(span_ctx)
      assert Otel.API.Trace.Span.recording?(span_ctx) == false
    end

    test "with_span — happy path ends the span with end_time set; calls every processor" do
      restart_sdk(trace: [processors: [{TestProcessor, %{test_pid: self()}}]])

      result =
        Otel.API.Trace.with_span(tracer_for(), "with_span_test", [], fn _ -> :my_result end)

      assert result == :my_result
      assert_receive {:on_end, ended}
      assert ended.name == "with_span_test"
      assert ended.is_recording == false
      assert ended.end_time != nil
    end

    # Spec trace/exceptions.md L35: status.description = exception's
    # human message (not the formatted "** (RuntimeError) ..." form).
    # raise / :erlang.error / throw all become recorded exception
    # events with code=:error and a binary description.
    test "with_span records raise/:erlang.error/throw as exception events with status=error" do
      restart_sdk(trace: [processors: [{TestProcessor, %{test_pid: self()}}]])
      tracer = tracer_for()

      assert_raise RuntimeError, "boom", fn ->
        Otel.API.Trace.with_span(tracer, "raise_span", [], fn _ -> raise "boom" end)
      end

      assert_receive {:on_end, ended_raise}
      assert %Otel.API.Trace.Status{code: :error, description: "boom"} = ended_raise.status
      [event] = ended_raise.events
      assert event.name == "exception"
      assert event.attributes["exception.message"] == "boom"
      assert event.attributes["exception.type"] == "RuntimeError"

      assert_raise ErlangError, fn ->
        Otel.API.Trace.with_span(tracer, "erlang_span", [], fn _ ->
          :erlang.error(:some_reason)
        end)
      end

      assert_receive {:on_end, ended_erlang}
      assert %Otel.API.Trace.Status{code: :error} = ended_erlang.status
      assert is_binary(ended_erlang.status.description)

      catch_throw(Otel.API.Trace.with_span(tracer, "throw_span", [], fn _ -> throw(:thrown) end))

      assert_receive {:on_end, ended_throw}
      assert %Otel.API.Trace.Status{code: :error} = ended_throw.status
      assert is_binary(ended_throw.status.description)
    end
  end
end
