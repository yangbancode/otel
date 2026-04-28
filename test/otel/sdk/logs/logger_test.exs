defmodule Otel.SDK.Logs.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defmodule CollectorProcessor do
    @moduledoc false

    def on_emit(record, _ctx, %{test_pid: pid}) do
      send(pid, {:log_record, record})
      :ok
    end

    def shutdown(_config, _timeout \\ 5000), do: :ok
    def force_flush(_config, _timeout \\ 5000), do: :ok
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

  defp logger_for(scope_name, version \\ "1.0.0") do
    {_mod, config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(
        Otel.SDK.Logs.LoggerProvider,
        %Otel.API.InstrumentationScope{name: scope_name, version: version}
      )

    {Otel.SDK.Logs.Logger, config}
  end

  defp logger_with_limits(limit_overrides) do
    restart_sdk(
      logs: [
        processors: [{CollectorProcessor, %{test_pid: self()}}],
        log_record_limits: struct(Otel.SDK.Logs.LogRecordLimits, limit_overrides)
      ]
    )

    logger_for("lib")
  end

  setup do
    restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])
    %{logger: logger_for("test_lib")}
  end

  describe "emit/3 — record enrichment" do
    test "fills observed_timestamp from current time when missing; preserves user value when set",
         %{logger: logger} do
      ctx = Otel.API.Ctx.current()

      before = System.system_time(:nanosecond)
      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{body: "auto"})
      assert_receive {:log_record, auto}
      assert auto.observed_timestamp >= before

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        body: "manual",
        observed_timestamp: 42
      })

      assert_receive {:log_record, manual}
      assert manual.observed_timestamp == 42
    end

    test "decorates with scope, resource, trace context, and proto3 defaults", %{logger: logger} do
      Otel.SDK.Logs.Logger.emit(logger, Otel.API.Ctx.current(), %Otel.API.Logs.LogRecord{})
      assert_receive {:log_record, record}

      assert record.scope.name == "test_lib"
      assert record.scope.version == "1.0.0"
      assert %Otel.SDK.Resource{} = record.resource
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
      Otel.SDK.Logs.Logger.emit(logger, Otel.API.Ctx.current(), %Otel.API.Logs.LogRecord{
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

  test "emit via Otel.API.Logs.Logger dispatch reaches the SDK Logger", %{logger: logger} do
    Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{body: "via API"})
    assert_receive {:log_record, %{body: "via API"}}
  end

  describe "exception handling" do
    test "exception fields populate exception.type / exception.message attributes; user values win",
         %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      ex = %RuntimeError{message: "auto"}

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{body: "e", exception: ex})
      assert_receive {:log_record, auto}
      assert auto.attributes["exception.type"] == "Elixir.RuntimeError"
      assert auto.attributes["exception.message"] == "auto"

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        body: "e",
        exception: ex,
        attributes: %{"exception.message" => "user override"}
      })

      assert_receive {:log_record, override}
      assert override.attributes["exception.message"] == "user override"
      assert override.attributes["exception.type"] == "Elixir.RuntimeError"
    end

    test "no exception → no exception attributes injected", %{logger: logger} do
      Otel.SDK.Logs.Logger.emit(logger, Otel.API.Ctx.current(), %Otel.API.Logs.LogRecord{
        body: "normal"
      })

      assert_receive {:log_record, record}
      refute Map.has_key?(record.attributes, "exception.type")
    end
  end

  describe "Logger.enabled?/2" do
    test "true when at least one processor exists; false when none", %{logger: logger} do
      assert Otel.SDK.Logs.Logger.enabled?(logger, [])

      restart_sdk(logs: [exporter: :none])
      refute Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end
  end

  describe "log_record_limits enforcement" do
    test "value-length limit truncates strings; count limit drops attributes; both report dropped_attributes_count" do
      logger = logger_with_limits(attribute_value_length_limit: 5)
      ctx = Otel.API.Ctx.current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        attributes: %{"key" => "abcdefgh"}
      })

      assert_receive {:log_record, truncated}
      assert truncated.attributes["key"] == "abcde"
      assert truncated.dropped_attributes_count == 0

      logger = logger_with_limits(attribute_count_limit: 2)

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        attributes: %{"a" => 1, "b" => 2, "c" => 3, "d" => 4}
      })

      assert_receive {:log_record, dropped}
      assert map_size(dropped.attributes) == 2
      assert dropped.dropped_attributes_count == 2
    end

    test "warns once with the right phrase when limits trim; silent when within limits" do
      drop_log =
        capture_log(fn ->
          Otel.SDK.Logs.Logger.emit(
            logger_with_limits(attribute_count_limit: 1),
            Otel.API.Ctx.current(),
            %Otel.API.Logs.LogRecord{attributes: %{"a" => 1, "b" => 2, "c" => 3}}
          )
        end)

      assert drop_log =~ "log record limits applied"
      assert drop_log =~ "dropped 2 attribute"

      truncate_log =
        capture_log(fn ->
          Otel.SDK.Logs.Logger.emit(
            logger_with_limits(attribute_value_length_limit: 3),
            Otel.API.Ctx.current(),
            %Otel.API.Logs.LogRecord{attributes: %{"key" => "abcdefg"}}
          )
        end)

      assert truncate_log =~ "log record limits applied"
      assert truncate_log =~ "truncated"

      # When both effects occur in one record, drop wins; only one warning.
      both_log =
        capture_log(fn ->
          Otel.SDK.Logs.Logger.emit(
            logger_with_limits(attribute_count_limit: 1, attribute_value_length_limit: 3),
            Otel.API.Ctx.current(),
            %Otel.API.Logs.LogRecord{attributes: %{"a" => "abcdef", "b" => "ghijkl"}}
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
          Otel.SDK.Logs.Logger.emit(
            logger_for("lib"),
            Otel.API.Ctx.current(),
            %Otel.API.Logs.LogRecord{attributes: %{"a" => 1, "b" => "short"}}
          )
        end)

      refute silent_log =~ "log record limits applied"
    end
  end
end
