defmodule Otel.SDK.Logs.LogRecordProcessorTest do
  use ExUnit.Case

  defmodule CollectorProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(log_record, config) do
      send(config.test_pid, {:on_emit, log_record})
      :ok
    end

    @impl true
    def enabled?(_opts, _config), do: true

    @impl true
    def shutdown(config) do
      send(config.test_pid, :shutdown)
      :ok
    end

    @impl true
    def force_flush(config) do
      send(config.test_pid, :force_flush)
      :ok
    end
  end

  defmodule DisabledProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(_log_record, _config), do: :ok

    @impl true
    def enabled?(_opts, _config), do: false

    @impl true
    def shutdown(_config), do: :ok

    @impl true
    def force_flush(_config), do: :ok
  end

  defmodule MutatingProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(log_record, config) do
      mutated = Map.put(log_record, :severity_text, "MUTATED")
      send(config.test_pid, {:mutated, mutated})
      :ok
    end

    @impl true
    def enabled?(_opts, _config), do: true

    @impl true
    def shutdown(_config), do: :ok

    @impl true
    def force_flush(_config), do: :ok
  end

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  describe "processor receives log records" do
    test "on_emit is called with log record" do
      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}]
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "test_lib")
      logger = {Otel.SDK.Logs.Logger, config}

      Otel.API.Logs.Logger.emit(logger, %{body: "hello"})
      assert_receive {:on_emit, record}
      assert record.body == "hello"
      assert record.scope.name == "test_lib"
      assert %Otel.SDK.Resource{} = record.resource
    end
  end

  describe "processor lifecycle" do
    test "shutdown invokes processor shutdown" do
      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}]
          }
        )

      Otel.SDK.Logs.LoggerProvider.shutdown(pid)
      assert_receive :shutdown
    end

    test "force_flush invokes processor force_flush" do
      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}]
          }
        )

      Otel.SDK.Logs.LoggerProvider.force_flush(pid)
      assert_receive :force_flush
    end
  end

  describe "enabled? with processor-level check" do
    test "returns true when processor enabled" do
      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}]
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "lib")
      logger = {Otel.SDK.Logs.Logger, config}
      assert Otel.SDK.Logs.Logger.enabled?(logger, [])
    end

    test "returns false when all processors disabled" do
      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{DisabledProcessor, %{}}]
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "lib")
      logger = {Otel.SDK.Logs.Logger, config}
      refute Otel.SDK.Logs.Logger.enabled?(logger, [])
    end

    test "returns true when at least one processor is enabled" do
      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [
              {DisabledProcessor, %{}},
              {CollectorProcessor, %{test_pid: self()}}
            ]
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "lib")
      logger = {Otel.SDK.Logs.Logger, config}
      assert Otel.SDK.Logs.Logger.enabled?(logger, [])
    end

    test "returns false with no processors" do
      {:ok, pid} = Otel.SDK.Logs.LoggerProvider.start_link(config: %{})
      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "lib")
      logger = {Otel.SDK.Logs.Logger, config}
      refute Otel.SDK.Logs.Logger.enabled?(logger, [])
    end
  end

  describe "ReadWriteLogRecord" do
    test "log record contains all required fields" do
      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}]
          }
        )

      {_mod, config} = Otel.SDK.Logs.LoggerProvider.get_logger(pid, "test_lib", "1.0.0")
      logger = {Otel.SDK.Logs.Logger, config}

      Otel.API.Logs.Logger.emit(logger, %{
        timestamp: 1_000_000,
        severity_number: 9,
        severity_text: "INFO",
        body: "structured",
        attributes: %{"key" => "val"},
        event_name: "my.event"
      })

      assert_receive {:on_emit, record}
      assert record.timestamp == 1_000_000
      assert record.severity_number == 9
      assert record.severity_text == "INFO"
      assert record.body == "structured"
      assert record.attributes == %{"key" => "val"}
      assert record.event_name == "my.event"
      assert record.scope.name == "test_lib"
      assert record.scope.version == "1.0.0"
      assert %Otel.SDK.Resource{} = record.resource
      assert Map.has_key?(record, :trace_id)
      assert Map.has_key?(record, :span_id)
      assert Map.has_key?(record, :trace_flags)
      assert Map.has_key?(record, :observed_timestamp)
      assert Map.has_key?(record, :dropped_attributes_count)
    end
  end
end
