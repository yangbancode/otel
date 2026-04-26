defmodule Otel.SDK.Logs.LogRecordProcessor.SimpleTest do
  use ExUnit.Case

  defmodule TestExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def export(log_records, config) do
      send(config.test_pid, {:exported, log_records})
      :ok
    end

    @impl true
    def force_flush(config) do
      send(config.test_pid, :exporter_force_flush)
      :ok
    end

    @impl true
    def shutdown(config) do
      send(config.test_pid, :exporter_shutdown)
      :ok
    end
  end

  defmodule IgnoredExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(_config), do: :ignore

    @impl true
    def export(_log_records, _config), do: :ok

    @impl true
    def force_flush(_config), do: :ok

    @impl true
    def shutdown(_config), do: :ok
  end

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)
    :ok
  end

  describe "start_link and init" do
    test "starts with exporter" do
      pid =
        start_supervised!(
          {Otel.SDK.Logs.LogRecordProcessor.Simple,
           %{exporter: {TestExporter, %{test_pid: self()}}}}
        )

      assert Process.alive?(pid)
    end

    test "starts with ignored exporter" do
      pid =
        start_supervised!(
          {Otel.SDK.Logs.LogRecordProcessor.Simple, %{exporter: {IgnoredExporter, %{}}}}
        )

      assert Process.alive?(pid)
    end
  end

  describe "on_emit/2" do
    test "exports log record immediately" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      )

      log_record = %Otel.SDK.Logs.LogRecord{body: "hello", severity_number: 9}

      Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(log_record, %{}, %{})
      assert_receive {:exported, [^log_record]}
    end

    test "no-op when exporter is ignored" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple, %{exporter: {IgnoredExporter, %{}}}}
      )

      assert :ok ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(
                 %Otel.SDK.Logs.LogRecord{body: "test"},
                 %{},
                 %{}
               )
    end
  end

  describe "enabled?/2" do
    test "returns true" do
      assert Otel.SDK.Logs.LogRecordProcessor.Simple.enabled?([], %{}, %{})
    end
  end

  describe "shutdown/1" do
    test "shuts down exporter" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      )

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{})
      assert_receive :exporter_shutdown
    end

    test "shutdown invokes exporter force_flush before exporter shutdown" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      )

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{})
      assert_receive :exporter_force_flush
      assert_receive :exporter_shutdown
    end

    test "shutdown of ignored exporter returns :ok" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple, %{exporter: {IgnoredExporter, %{}}}}
      )

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{})
    end

    test "second shutdown returns error" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      )

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{})

      assert {:error, :already_shut_down} ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{})
    end

    test "emit after shutdown is no-op" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      )

      Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{})

      assert :ok ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(
                 %Otel.SDK.Logs.LogRecord{body: "late"},
                 %{},
                 %{}
               )

      refute_receive {:exported, _}
    end
  end

  describe "force_flush/1" do
    test "invokes exporter force_flush" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      )

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(%{})
      assert_receive :exporter_force_flush
    end

    test "returns :ok when exporter is ignored" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple, %{exporter: {IgnoredExporter, %{}}}}
      )

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(%{})
    end
  end

  describe "integration with LoggerProvider" do
    test "end-to-end emit through provider" do
      start_supervised!(
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      )

      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Logs.LogRecordProcessor.Simple, %{}}
            ]
          }
        )

      {_mod, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(provider_pid, %Otel.API.InstrumentationScope{
          name: "test_lib"
        })

      logger = {Otel.SDK.Logs.Logger, config}

      Otel.API.Logs.Logger.emit(
        logger,
        %Otel.API.Logs.LogRecord{body: "e2e test", severity_number: 9}
      )

      assert_receive {:exported, [record]}
      assert record.body == "e2e test"
      assert record.scope.name == "test_lib"
    end
  end
end
