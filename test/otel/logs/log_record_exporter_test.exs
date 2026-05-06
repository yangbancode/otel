defmodule Otel.Logs.LogRecordExporterTest do
  # async: false — mutates `:otel` Application env
  # (`:req_options`) and shares the global `LogRecordStorage`
  # ETS table.
  use ExUnit.Case, async: false

  @log_record Otel.Logs.LogRecord.new(%{
                body: "test log message",
                severity_number: 9,
                severity_text: "INFO",
                timestamp: 1_000_000,
                observed_timestamp: 2_000_000,
                attributes: %{"key" => "value"},
                scope: Otel.InstrumentationScope.new(%{name: "test_lib"}),
                resource: Otel.Resource.new(%{attributes: %{"service.name" => "test"}})
              })

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.delete_env(:otel, :req_options)
      Application.stop(:otel)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  describe "force_flush/1" do
    test "empty storage → :ok (no HTTP request sent)" do
      start_server_and_configure(200)

      assert :ok = Otel.Logs.LogRecordExporter.force_flush()
      refute_receive :request_received, 200
    end

    test "queued records → drain + HTTP POST + storage emptied" do
      start_server_and_configure(200)

      Otel.Logs.LogRecordStorage.insert(@log_record)

      assert :ok = Otel.Logs.LogRecordExporter.force_flush()
      assert_receive :request_received, 5_000
      assert [] = Otel.Logs.LogRecordStorage.take(10)
    end
  end

  # --- Test helpers ---

  defp start_server_and_configure(status_code) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    parent = self()
    pid = spawn_link(fn -> accept_loop(listen, status_code, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listen)
      ref = Process.monitor(pid)
      receive do: ({:DOWN, ^ref, _, _, _} -> :ok), after: (1_000 -> :ok)
    end)

    Application.put_env(:otel, :req_options, base_url: "http://localhost:#{port}")
    :ok
  end

  defp accept_loop(listen, status_code, parent) do
    case :gen_tcp.accept(listen, 1_000) do
      {:ok, socket} ->
        _ = :gen_tcp.recv(socket, 0, 5_000)
        send(parent, :request_received)
        :gen_tcp.send(socket, "HTTP/1.1 #{status_code} OK\r\ncontent-length: 0\r\n\r\n")
        :gen_tcp.close(socket)
        accept_loop(listen, status_code, parent)

      {:error, :timeout} ->
        accept_loop(listen, status_code, parent)

      _ ->
        :ok
    end
  end
end
