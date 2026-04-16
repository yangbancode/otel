defmodule Otel.SDK.Logs.LogRecordExporterTest do
  use ExUnit.Case, async: true

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
      send(config.test_pid, :force_flush)
      :ok
    end

    @impl true
    def shutdown(config) do
      send(config.test_pid, :shutdown)
      :ok
    end
  end

  defmodule FailingExporter do
    @moduledoc false
    @behaviour Otel.SDK.Logs.LogRecordExporter

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def export(_log_records, _config), do: :error

    @impl true
    def force_flush(_config), do: :ok

    @impl true
    def shutdown(_config), do: :ok
  end

  describe "behaviour implementation" do
    test "init returns {:ok, state}" do
      {:ok, state} = TestExporter.init(%{test_pid: self()})
      assert state.test_pid == self()
    end

    test "export sends log records and returns :ok" do
      {:ok, state} = TestExporter.init(%{test_pid: self()})

      records = [
        %{body: "log 1", severity_number: 9},
        %{body: "log 2", severity_number: 17}
      ]

      assert :ok == TestExporter.export(records, state)
      assert_receive {:exported, ^records}
    end

    test "export returns :error on failure" do
      {:ok, state} = FailingExporter.init(%{})
      assert :error == FailingExporter.export([%{body: "test"}], state)
    end

    test "force_flush returns :ok" do
      {:ok, state} = TestExporter.init(%{test_pid: self()})
      assert :ok == TestExporter.force_flush(state)
      assert_receive :force_flush
    end

    test "shutdown returns :ok" do
      {:ok, state} = TestExporter.init(%{test_pid: self()})
      assert :ok == TestExporter.shutdown(state)
      assert_receive :shutdown
    end
  end
end
