defmodule Otel.Logs.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule CollectorProcessor do
    @moduledoc """
    Test substitute for `Otel.Logs.LogRecordProcessor`. Receives
    `:gen_statem.cast({:add_record, record})` from
    `Otel.Logs.Logger.emit/3` via the hardcoded name and forwards
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

  defp logger, do: Otel.Logs.LoggerProvider.get_logger()

  # Build a Logger struct with custom `log_record_limits`. Limits are
  # no longer carried in `:persistent_term`; the Provider's `get_logger/0`
  # always stamps the spec defaults, so tests that need to exercise
  # limit enforcement construct the struct directly.
  defp logger_with_limits(limit_overrides) do
    restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])

    %Otel.Logs.Logger{
      config: %{
        scope: %Otel.InstrumentationScope{},
        resource: Otel.Logs.LoggerProvider.resource(),
        log_record_limits: struct(Otel.Logs.LogRecordLimits, limit_overrides)
      }
    }
  end

  setup do
    restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])
    %{logger: logger()}
  end

  describe "emit/3 — record enrichment" do
    test "fills observed_timestamp from current time when missing; preserves user value when set",
         %{logger: logger} do
      ctx = Otel.Ctx.current()

      before = System.system_time(:nanosecond)
      Otel.Logs.Logger.emit(logger, ctx, %Otel.Logs.LogRecord{body: "auto"})
      assert_receive {:log_record, auto}
      assert auto.observed_timestamp >= before

      Otel.Logs.Logger.emit(logger, ctx, %Otel.Logs.LogRecord{
        body: "manual",
        observed_timestamp: 42
      })

      assert_receive {:log_record, manual}
      assert manual.observed_timestamp == 42
    end

    test "decorates with scope, resource, trace context, and proto3 defaults", %{logger: logger} do
      Otel.Logs.Logger.emit(logger, Otel.Ctx.current(), %Otel.Logs.LogRecord{})
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

    test "passes user-provided fields through verbatim", %{logger: logger} do
      Otel.Logs.Logger.emit(logger, Otel.Ctx.current(), %Otel.Logs.LogRecord{
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

  test "emit via Otel.Logs.Logger dispatch reaches the SDK Logger", %{logger: logger} do
    Otel.Logs.Logger.emit(logger, %Otel.Logs.LogRecord{body: "via API"})
    assert_receive {:log_record, %{body: "via API"}}
  end

  describe "exception handling" do
    test "exception fields populate exception.type / exception.message attributes; user values win",
         %{logger: logger} do
      ctx = Otel.Ctx.current()
      ex = %RuntimeError{message: "auto"}

      Otel.Logs.Logger.emit(logger, ctx, %Otel.Logs.LogRecord{body: "e", exception: ex})
      assert_receive {:log_record, auto}
      assert auto.attributes["exception.type"] == "Elixir.RuntimeError"
      assert auto.attributes["exception.message"] == "auto"

      Otel.Logs.Logger.emit(logger, ctx, %Otel.Logs.LogRecord{
        body: "e",
        exception: ex,
        attributes: %{"exception.message" => "user override"}
      })

      assert_receive {:log_record, override}
      assert override.attributes["exception.message"] == "user override"
      assert override.attributes["exception.type"] == "Elixir.RuntimeError"
    end

    test "no exception → no exception attributes injected", %{logger: logger} do
      Otel.Logs.Logger.emit(logger, Otel.Ctx.current(), %Otel.Logs.LogRecord{
        body: "normal"
      })

      assert_receive {:log_record, record}
      refute Map.has_key?(record.attributes, "exception.type")
    end
  end

  describe "log_record_limits enforcement" do
    test "value-length limit truncates strings; count limit drops attributes; both report dropped_attributes_count" do
      logger = logger_with_limits(attribute_value_length_limit: 5)
      ctx = Otel.Ctx.current()

      Otel.Logs.Logger.emit(logger, ctx, %Otel.Logs.LogRecord{
        attributes: %{"key" => "abcdefgh"}
      })

      assert_receive {:log_record, truncated}
      assert truncated.attributes["key"] == "abcde"
      assert truncated.dropped_attributes_count == 0

      logger = logger_with_limits(attribute_count_limit: 2)

      Otel.Logs.Logger.emit(logger, ctx, %Otel.Logs.LogRecord{
        attributes: %{"a" => 1, "b" => 2, "c" => 3, "d" => 4}
      })

      assert_receive {:log_record, dropped}
      assert map_size(dropped.attributes) == 2
      assert dropped.dropped_attributes_count == 2
    end

    test "warns once with the right phrase when limits trim; silent when within limits" do
      drop_log =
        capture_log(fn ->
          Otel.Logs.Logger.emit(
            logger_with_limits(attribute_count_limit: 1),
            Otel.Ctx.current(),
            %Otel.Logs.LogRecord{attributes: %{"a" => 1, "b" => 2, "c" => 3}}
          )
        end)

      assert drop_log =~ "log record limits applied"
      assert drop_log =~ "dropped 2 attribute"

      truncate_log =
        capture_log(fn ->
          Otel.Logs.Logger.emit(
            logger_with_limits(attribute_value_length_limit: 3),
            Otel.Ctx.current(),
            %Otel.Logs.LogRecord{attributes: %{"key" => "abcdefg"}}
          )
        end)

      assert truncate_log =~ "log record limits applied"
      assert truncate_log =~ "truncated"

      # When both effects occur in one record, drop wins; only one warning.
      both_log =
        capture_log(fn ->
          Otel.Logs.Logger.emit(
            logger_with_limits(attribute_count_limit: 1, attribute_value_length_limit: 3),
            Otel.Ctx.current(),
            %Otel.Logs.LogRecord{attributes: %{"a" => "abcdef", "b" => "ghijkl"}}
          )
        end)

      lines =
        both_log
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "log record limits applied"))

      assert length(lines) == 1
      assert both_log =~ "dropped 1 attribute"
      refute both_log =~ "truncated"

      restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])

      silent_log =
        capture_log(fn ->
          Otel.Logs.Logger.emit(
            logger(),
            Otel.Ctx.current(),
            %Otel.Logs.LogRecord{attributes: %{"a" => 1, "b" => "short"}}
          )
        end)

      refute silent_log =~ "log record limits applied"
    end
  end
end
