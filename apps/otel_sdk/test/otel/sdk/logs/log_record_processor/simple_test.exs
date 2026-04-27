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

  defmodule SlowExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def export(_log_records, config) do
      Process.sleep(config.delay_ms)
      :ok
    end

    @impl true
    def force_flush(config) do
      Process.sleep(config.delay_ms)
      :ok
    end

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
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      assert Process.alive?(pid)
      :gen_statem.stop(pid)
    end
  end

  describe "on_emit/2" do
    test "exports log record immediately" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      log_record = %Otel.SDK.Logs.LogRecord{body: "hello", severity_number: 9}

      Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(log_record, %{}, %{pid: pid})
      assert_receive {:exported, [^log_record]}
    end
  end

  describe "enabled?/4" do
    test "returns true" do
      assert Otel.SDK.Logs.LogRecordProcessor.Simple.enabled?(%{}, %{}, [], %{})
    end
  end

  describe "shutdown/1" do
    test "shuts down exporter" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: pid})
      assert_receive :exporter_shutdown
    end

    test "shutdown invokes exporter force_flush before exporter shutdown" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: pid})
      assert_receive :exporter_force_flush
      assert_receive :exporter_shutdown
    end

    test "second shutdown returns {:error, :already_shutdown}" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: pid})

      assert {:error, :already_shutdown} ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: pid})
    end

    test "emit after shutdown is no-op" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: pid})

      assert :ok ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(
                 %Otel.SDK.Logs.LogRecord{body: "late"},
                 %{},
                 %{pid: pid}
               )

      refute_receive {:exported, _}
    end
  end

  describe "force_flush/1" do
    test "invokes exporter force_flush" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(%{pid: pid})
      assert_receive :exporter_force_flush
    end

    test "force_flush after shutdown returns {:error, :already_shutdown}" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {TestExporter, %{test_pid: self()}}
        })

      assert :ok == Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: pid})

      assert {:error, :already_shutdown} ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(%{pid: pid})
    end
  end

  describe "caller-supplied timeout" do
    test "force_flush/2 returns {:error, :timeout} when the budget is exceeded" do
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {SlowExporter, %{delay_ms: 1000}}
        })

      assert {:error, :timeout} ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(%{pid: pid}, 50)
    end

    test "shutdown/2 returns {:error, :timeout} when the budget is exceeded" do
      # `terminate/3` runs the exporter's `force_flush/1`. SlowExporter
      # sleeps `delay_ms` there, so a 50ms shutdown budget against a
      # 1000ms exporter must time out.
      {:ok, pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {SlowExporter, %{delay_ms: 1000}}
        })

      assert {:error, :timeout} ==
               Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: pid}, 50)
    end
  end

  describe "integration with LoggerProvider" do
    test "end-to-end emit through provider" do
      Application.stop(:otel_sdk)

      Application.put_env(:otel_sdk, :logs,
        processors: [
          {Otel.SDK.Logs.LogRecordProcessor.Simple,
           %{exporter: {TestExporter, %{test_pid: self()}}}}
        ]
      )

      Application.ensure_all_started(:otel_sdk)

      on_exit(fn ->
        Application.stop(:otel_sdk)
        Application.delete_env(:otel_sdk, :logs)
      end)

      {_mod, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(
          Otel.SDK.Logs.LoggerProvider,
          %Otel.API.InstrumentationScope{name: "test_lib"}
        )

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
