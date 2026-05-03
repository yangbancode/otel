defmodule Otel.Logs.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule CollectorProcessor do
    @moduledoc """
    Test substitute for `Otel.Logs.LogRecordProcessor`. Receives
    `:gen_statem.cast({:add_record, record})` from
    `Otel.Logs.Logger.emit/2` via the hardcoded name and forwards
    each record to the test pid.
    """

    use GenServer

    def start_link(%{test_pid: _pid} = config),
      do: GenServer.start_link(__MODULE__, config, name: Otel.Logs.LogRecordProcessor)

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def handle_cast({:add_record, record}, %{test_pid: pid} = state) do
      send(pid, {:log_record, record})
      {:noreply, state}
    end

    @impl true
    def handle_call(_msg, _from, state), do: {:reply, :ok, state}
  end

  defp restart_sdk(env), do: Otel.TestSupport.restart_with(env)

  setup do
    restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])
    :ok
  end

  describe "emit/2 — record enrichment" do
    test "fills observed_timestamp from current time when missing; preserves user value when set" do
      ctx = Otel.Ctx.current()

      before = System.system_time(:nanosecond)
      Otel.Logs.emit(ctx, %Otel.Logs.LogRecord{body: "auto"})
      assert_receive {:log_record, auto}
      assert auto.observed_timestamp >= before

      Otel.Logs.emit(ctx, %Otel.Logs.LogRecord{
        body: "manual",
        observed_timestamp: 42
      })

      assert_receive {:log_record, manual}
      assert manual.observed_timestamp == 42
    end

    test "decorates with scope, resource, trace context, and proto3 defaults" do
      Otel.Logs.emit(Otel.Ctx.current(), %Otel.Logs.LogRecord{})
      assert_receive {:log_record, record}

      assert record.scope.name == "otel"
      assert %Otel.Resource{} = record.resource
      assert record.timestamp == 0
      assert record.severity_number == 0
      assert record.severity_text == ""
      assert record.body == nil
      assert record.attributes == %{}
      assert record.event_name == ""

      for field <- [:trace_id, :span_id, :trace_flags] do
        assert Map.has_key?(record, field)
      end
    end

    test "passes user-provided fields through verbatim" do
      Otel.Logs.emit(Otel.Ctx.current(), %Otel.Logs.LogRecord{
        timestamp: 1_000_000,
        severity_number: 9,
        severity_text: "INFO",
        body: "structured log",
        attributes: %{"method" => "GET", "status" => 200},
        event_name: "http.request"
      })

      assert_receive {:log_record, record}
      assert record.timestamp == 1_000_000
      assert record.severity_number == 9
      assert record.severity_text == "INFO"
      assert record.body == "structured log"
      assert record.attributes == %{"method" => "GET", "status" => 200}
      assert record.event_name == "http.request"
    end
  end

  test "emit/1 dispatches with the implicit context" do
    Otel.Logs.emit(%Otel.Logs.LogRecord{body: "via API"})
    assert_receive {:log_record, %{body: "via API"}}
  end

  describe "exception handling" do
    test "exception fields populate exception.type / exception.message attributes; user values win" do
      ctx = Otel.Ctx.current()
      ex = %RuntimeError{message: "auto"}

      Otel.Logs.emit(ctx, %Otel.Logs.LogRecord{body: "e", exception: ex})
      assert_receive {:log_record, auto}
      assert auto.attributes["exception.type"] == "Elixir.RuntimeError"
      assert auto.attributes["exception.message"] == "auto"

      Otel.Logs.emit(ctx, %Otel.Logs.LogRecord{
        body: "e",
        exception: ex,
        attributes: %{"exception.message" => "user override"}
      })

      assert_receive {:log_record, override}
      assert override.attributes["exception.message"] == "user override"
      assert override.attributes["exception.type"] == "Elixir.RuntimeError"
    end

    test "no exception → no exception attributes injected" do
      Otel.Logs.emit(Otel.Ctx.current(), %Otel.Logs.LogRecord{body: "normal"})

      assert_receive {:log_record, record}
      refute Map.has_key?(record.attributes, "exception.type")
    end
  end

  describe "log_record_limits enforcement (default `attribute_count_limit: 128`)" do
    test "drops excess attributes and warns once" do
      attrs = for i <- 1..150, into: %{}, do: {"k#{i}", i}

      log =
        capture_log(fn ->
          Otel.Logs.emit(Otel.Ctx.current(), %Otel.Logs.LogRecord{attributes: attrs})
        end)

      assert_receive {:log_record, record}
      assert map_size(record.attributes) == 128
      assert record.dropped_attributes_count == 22

      assert log =~ "log record limits applied"
      assert log =~ "dropped 22 attributes"
    end
  end
end
