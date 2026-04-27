defmodule Otel.SDK.Logs.LogRecordProcessorTest do
  use ExUnit.Case

  defmodule CollectorProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(log_record, _ctx, config) do
      send(config.test_pid, {:on_emit, log_record})
      :ok
    end

    @impl true
    def enabled?(_ctx, _scope, _opts, _config), do: true

    @impl true
    def shutdown(config, _timeout \\ 5000) do
      send(config.test_pid, :shutdown)
      :ok
    end

    @impl true
    def force_flush(config, _timeout \\ 5000) do
      send(config.test_pid, :force_flush)
      :ok
    end
  end

  defmodule DisabledProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(_log_record, _ctx, _config), do: :ok

    @impl true
    def enabled?(_ctx, _scope, _opts, _config), do: false

    @impl true
    def shutdown(_config, _timeout \\ 5000), do: :ok

    @impl true
    def force_flush(_config, _timeout \\ 5000), do: :ok
  end

  defmodule MutatingProcessor do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(log_record, _ctx, config) do
      mutated = Map.put(log_record, :severity_text, "MUTATED")
      send(config.test_pid, {:mutated, mutated})
      :ok
    end

    @impl true
    def enabled?(_ctx, _scope, _opts, _config), do: true

    @impl true
    def shutdown(_config, _timeout \\ 5000), do: :ok

    @impl true
    def force_flush(_config, _timeout \\ 5000), do: :ok
  end

  defmodule MinimalProcessor do
    @moduledoc false
    # Intentionally omits enabled?/3 — it is an
    # @optional_callbacks per spec L420 (MAY implement). Used to
    # verify the SDK Logger's function_exported?/3 guard treats
    # an unimplemented enabled? as indeterminate → enabled.
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(_log_record, _ctx, _config), do: :ok

    @impl true
    def shutdown(_config, _timeout \\ 5000), do: :ok

    @impl true
    def force_flush(_config, _timeout \\ 5000), do: :ok
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

  defp logger_for(scope_name, version \\ "") do
    {_mod, config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(
        Otel.SDK.Logs.LoggerProvider,
        %Otel.API.InstrumentationScope{name: scope_name, version: version}
      )

    {Otel.SDK.Logs.Logger, config}
  end

  describe "processor receives log records" do
    test "on_emit is called with log record" do
      restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])
      logger = logger_for("test_lib")

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{body: "hello"})
      assert_receive {:on_emit, record}
      assert record.body == "hello"
      assert record.scope.name == "test_lib"
      assert %Otel.SDK.Resource{} = record.resource
    end
  end

  describe "processor lifecycle" do
    test "shutdown invokes processor shutdown" do
      restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])

      Otel.SDK.Logs.LoggerProvider.shutdown(Otel.SDK.Logs.LoggerProvider)
      assert_receive :shutdown
    end

    test "force_flush invokes processor force_flush" do
      restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])

      Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)
      assert_receive :force_flush
    end
  end

  describe "enabled? with processor-level check" do
    test "returns true when processor enabled" do
      restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])
      assert Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end

    test "returns false when all processors disabled" do
      restart_sdk(logs: [processors: [{DisabledProcessor, %{}}]])
      refute Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end

    test "returns true when at least one processor is enabled" do
      restart_sdk(
        logs: [
          processors: [
            {DisabledProcessor, %{}},
            {CollectorProcessor, %{test_pid: self()}}
          ]
        ]
      )

      assert Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end

    test "returns false with no processors" do
      restart_sdk(logs: [exporter: :none])
      refute Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end

    test "treats processor without enabled?/3 as indeterminate → enabled" do
      restart_sdk(logs: [processors: [{MinimalProcessor, %{}}]])
      assert Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end
  end

  describe "ReadWriteLogRecord" do
    test "log record contains all required fields" do
      restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])
      logger = logger_for("test_lib", "1.0.0")

      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
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
