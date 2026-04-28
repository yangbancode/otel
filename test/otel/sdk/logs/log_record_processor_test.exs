defmodule Otel.SDK.Logs.LogRecordProcessorTest do
  use ExUnit.Case, async: false

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

  defmodule MinimalProcessor do
    @moduledoc false
    # Intentionally omits enabled?/4 — it is an @optional_callback
    # per spec L420 (MAY implement). Used to verify the SDK Logger's
    # function_exported?/3 guard treats unimplemented enabled? as
    # indeterminate → enabled.
    @behaviour Otel.SDK.Logs.LogRecordProcessor

    @impl true
    def on_emit(_log_record, _ctx, _config), do: :ok
    @impl true
    def shutdown(_config, _timeout \\ 5000), do: :ok
    @impl true
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

  defp logger_for(scope_name, version \\ "") do
    {_mod, config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(
        Otel.SDK.Logs.LoggerProvider,
        %Otel.API.InstrumentationScope{name: scope_name, version: version}
      )

    {Otel.SDK.Logs.Logger, config}
  end

  test "on_emit receives a fully-shaped ReadWriteLogRecord (scope + resource + trace context fields)" do
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

    for field <- [
          :trace_id,
          :span_id,
          :trace_flags,
          :observed_timestamp,
          :dropped_attributes_count
        ] do
      assert Map.has_key?(record, field), "missing field: #{field}"
    end
  end

  test "LoggerProvider.shutdown/force_flush invoke the corresponding processor callback" do
    restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])

    Otel.SDK.Logs.LoggerProvider.force_flush(Otel.SDK.Logs.LoggerProvider)
    assert_receive :force_flush

    Otel.SDK.Logs.LoggerProvider.shutdown(Otel.SDK.Logs.LoggerProvider)
    assert_receive :shutdown
  end

  describe "Logger.enabled?/2 — true iff at least one processor's enabled?/4 returns true" do
    test "all processors enabled → true; all disabled → false; mixed → true" do
      restart_sdk(logs: [processors: [{CollectorProcessor, %{test_pid: self()}}]])
      assert Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])

      restart_sdk(logs: [processors: [{DisabledProcessor, %{}}]])
      refute Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])

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

    test "no processors → false" do
      restart_sdk(logs: [exporter: :none])
      refute Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end

    # Spec L420 — enabled? is optional. Missing implementation is
    # indeterminate, treated as enabled.
    test "processor without enabled?/4 callback is treated as enabled" do
      restart_sdk(logs: [processors: [{MinimalProcessor, %{}}]])
      assert Otel.SDK.Logs.Logger.enabled?(logger_for("lib"), [])
    end
  end
end
