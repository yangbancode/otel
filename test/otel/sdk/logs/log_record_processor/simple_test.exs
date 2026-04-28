defmodule Otel.SDK.Logs.LogRecordProcessor.SimpleTest do
  use ExUnit.Case, async: false

  defmodule TestExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}
    @impl true
    def export(log_records, %{test_pid: pid}) do
      send(pid, {:exported, log_records})
      :ok
    end

    @impl true
    def force_flush(%{test_pid: pid}) do
      send(pid, :exporter_force_flush)
      :ok
    end

    @impl true
    def shutdown(%{test_pid: pid}) do
      send(pid, :exporter_shutdown)
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
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
    :ok
  end

  defp start_processor do
    {:ok, pid} =
      Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
        exporter: {TestExporter, %{test_pid: self()}}
      })

    %{pid: pid}
  end

  test "on_emit/3 forwards the log record to the exporter immediately" do
    config = start_processor()
    record = %Otel.SDK.Logs.LogRecord{body: "hello", severity_number: 9}

    Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(record, %{}, config)

    assert_receive {:exported, [^record]}
  end

  test "enabled?/4 always returns true" do
    assert Otel.SDK.Logs.LogRecordProcessor.Simple.enabled?(%{}, %{}, [], %{})
  end

  describe "shutdown/1,2" do
    test "drains via exporter force_flush, then exporter shutdown; emit after shutdown is no-op" do
      config = start_processor()

      assert :ok = Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(config)
      assert_receive :exporter_force_flush
      assert_receive :exporter_shutdown

      assert :ok =
               Otel.SDK.Logs.LogRecordProcessor.Simple.on_emit(
                 %Otel.SDK.Logs.LogRecord{body: "late"},
                 %{},
                 config
               )

      refute_receive {:exported, _}
    end

    test "second shutdown / force_flush after first → {:error, :already_shutdown}" do
      config = start_processor()
      :ok = Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(config)

      assert {:error, :already_shutdown} =
               Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(config)

      assert {:error, :already_shutdown} =
               Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(config)
    end

    test "shutdown / force_flush exceeding the timeout budget → {:error, :timeout}" do
      {:ok, shut_pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {SlowExporter, %{delay_ms: 1000}}
        })

      assert {:error, :timeout} =
               Otel.SDK.Logs.LogRecordProcessor.Simple.shutdown(%{pid: shut_pid}, 50)

      {:ok, flush_pid} =
        Otel.SDK.Logs.LogRecordProcessor.Simple.start_link(%{
          exporter: {SlowExporter, %{delay_ms: 1000}}
        })

      assert {:error, :timeout} =
               Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(%{pid: flush_pid}, 50)
    end
  end

  test "force_flush/1 invokes exporter.force_flush" do
    config = start_processor()
    assert :ok = Otel.SDK.Logs.LogRecordProcessor.Simple.force_flush(config)
    assert_receive :exporter_force_flush
  end

  test "end-to-end: emit through LoggerProvider exports via the Simple processor" do
    Application.stop(:otel)

    Application.put_env(:otel, :logs,
      processors: [
        {Otel.SDK.Logs.LogRecordProcessor.Simple,
         %{exporter: {TestExporter, %{test_pid: self()}}}}
      ]
    )

    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.delete_env(:otel, :logs)
    end)

    {_mod, config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(
        Otel.SDK.Logs.LoggerProvider,
        %Otel.API.InstrumentationScope{name: "test_lib"}
      )

    Otel.API.Logs.Logger.emit(
      {Otel.SDK.Logs.Logger, config},
      %Otel.API.Logs.LogRecord{body: "e2e test", severity_number: 9}
    )

    assert_receive {:exported, [record]}
    assert record.body == "e2e test"
    assert record.scope.name == "test_lib"
  end
end
