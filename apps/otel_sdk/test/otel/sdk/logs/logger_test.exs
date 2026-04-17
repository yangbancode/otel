defmodule Otel.SDK.Logs.LoggerTest do
  use ExUnit.Case

  defmodule CollectorProcessor do
    @moduledoc false
    def on_emit(record, config) do
      send(config.test_pid, {:log_record, record})
      :ok
    end

    def shutdown(_config), do: :ok
    def force_flush(_config), do: :ok
  end

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} =
      Otel.SDK.Logs.LoggerProvider.start_link(
        config: %{
          processors: [{CollectorProcessor, %{test_pid: self()}}]
        }
      )

    {_module, logger_config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "test_lib", "1.0.0")
    logger = {Otel.SDK.Logs.Logger, logger_config}

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{logger: logger}
  end

  defp attr(k, v) when is_binary(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.string(v))
  end

  defp attr(k, v) when is_integer(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.int(v))
  end

  defp find_attr(attributes, key) do
    case Enum.find(attributes, &(&1.key == key)) do
      nil -> nil
      %Otel.API.Common.Attribute{value: %Otel.API.Common.AnyValue{value: v}} -> v
    end
  end

  describe "emit/3" do
    test "dispatches to processor", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{body: Otel.API.Common.AnyValue.string("hello")})

      assert_receive {:log_record, record}
      assert record.body == Otel.API.Common.AnyValue.string("hello")
    end

    test "sets observed_timestamp when not provided", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()
      before = System.system_time(:nanosecond)

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{body: Otel.API.Common.AnyValue.string("test")})

      assert_receive {:log_record, record}
      assert record.observed_timestamp >= before
    end

    test "preserves user-provided observed_timestamp", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{
        body: Otel.API.Common.AnyValue.string("test"),
        observed_timestamp: 42
      })

      assert_receive {:log_record, record}
      assert record.observed_timestamp == 42
    end

    test "populates all default fields", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %{})
      assert_receive {:log_record, record}
      assert record.timestamp == nil
      assert record.severity_number == nil
      assert record.severity_text == nil
      assert record.body == nil
      assert record.attributes == []
      assert record.event_name == nil
    end

    test "includes scope and resource", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{body: Otel.API.Common.AnyValue.string("scoped")})

      assert_receive {:log_record, record}
      assert record.scope.name == "test_lib"
      assert record.scope.version == "1.0.0"
      assert %Otel.SDK.Resource{} = record.resource
    end

    test "extracts trace context", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{body: Otel.API.Common.AnyValue.string("traced")})

      assert_receive {:log_record, record}
      assert Map.has_key?(record, :trace_id)
      assert Map.has_key?(record, :span_id)
      assert Map.has_key?(record, :trace_flags)
    end

    test "passes all user-provided fields through", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{
        timestamp: 1_000_000,
        severity_number: 9,
        severity_text: "INFO",
        body: Otel.API.Common.AnyValue.string("structured log"),
        attributes: [attr("method", "GET"), attr("status", 200)],
        event_name: "http.request"
      })

      assert_receive {:log_record, record}
      assert record.timestamp == 1_000_000
      assert record.severity_number == 9
      assert record.severity_text == "INFO"
      assert record.body == Otel.API.Common.AnyValue.string("structured log")
      assert find_attr(record.attributes, "method") == "GET"
      assert find_attr(record.attributes, "status") == 200
      assert record.event_name == "http.request"
    end
  end

  describe "enabled?/2" do
    test "returns true when processors exist", %{logger: logger} do
      assert Otel.SDK.Logs.Logger.enabled?(logger, [])
    end

    test "returns false when no processors" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} = Otel.SDK.Logs.LoggerProvider.start_link(config: %{})
      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "lib")
      logger = {Otel.SDK.Logs.Logger, config}

      refute Otel.SDK.Logs.Logger.enabled?(logger, [])
    end
  end

  describe "exception handling" do
    test "sets exception attributes from exception", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()
      exception = %RuntimeError{message: "something went wrong"}

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{
        body: Otel.API.Common.AnyValue.string("error"),
        exception: exception
      })

      assert_receive {:log_record, record}
      assert find_attr(record.attributes, "exception.type") == "Elixir.RuntimeError"
      assert find_attr(record.attributes, "exception.message") == "something went wrong"
    end

    test "user attributes take precedence over exception attributes", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()
      exception = %RuntimeError{message: "auto"}

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{
        body: Otel.API.Common.AnyValue.string("error"),
        exception: exception,
        attributes: [attr("exception.message", "user override")]
      })

      assert_receive {:log_record, record}
      assert find_attr(record.attributes, "exception.message") == "user override"
      assert find_attr(record.attributes, "exception.type") == "Elixir.RuntimeError"
    end

    test "no exception does not set exception attributes", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{body: Otel.API.Common.AnyValue.string("normal")})

      assert_receive {:log_record, record}
      refute Enum.any?(record.attributes, &(&1.key == "exception.type"))
    end
  end

  describe "attribute limits" do
    test "truncates attribute values when limit set" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}],
            log_record_limits: %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 5}
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "lib")
      logger = {Otel.SDK.Logs.Logger, config}

      ctx = Otel.API.Ctx.get_current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %{attributes: [attr("key", "abcdefgh")]})
      assert_receive {:log_record, record}
      assert find_attr(record.attributes, "key") == "abcde"
    end

    test "drops excess attributes when count limit set" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}],
            log_record_limits: %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 2}
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "lib")
      logger = {Otel.SDK.Logs.Logger, config}

      ctx = Otel.API.Ctx.get_current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %{
        attributes: [attr("a", 1), attr("b", 2), attr("c", 3), attr("d", 4)]
      })

      assert_receive {:log_record, record}
      assert length(record.attributes) == 2
      assert record.dropped_attributes_count == 2
    end

    test "dropped_attributes_count is 0 when within limit", %{logger: logger} do
      ctx = Otel.API.Ctx.get_current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %{attributes: [attr("a", 1)]})
      assert_receive {:log_record, record}
      assert record.dropped_attributes_count == 0
    end
  end

  describe "dispatch via API" do
    test "emit via API dispatch works", %{logger: logger} do
      Otel.API.Logs.Logger.emit(logger, %{body: Otel.API.Common.AnyValue.string("via API")})
      assert_receive {:log_record, record}
      assert record.body == Otel.API.Common.AnyValue.string("via API")
    end
  end
end
