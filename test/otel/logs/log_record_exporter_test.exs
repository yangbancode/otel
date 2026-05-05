defmodule Otel.Logs.LogRecordExporterTest do
  # async: false — mutates `:otel` Application env (`:req_options`).
  use ExUnit.Case, async: false

  @resource %Otel.Resource{attributes: %{"service.name" => "test"}}

  @log_record %Otel.Logs.LogRecord{
    body: "test log message",
    severity_number: 9,
    severity_text: "INFO",
    timestamp: 1_000_000,
    observed_timestamp: 2_000_000,
    attributes: %{"key" => "value"},
    event_name: "",
    scope: %Otel.InstrumentationScope{name: "test_lib"},
    resource: @resource,
    trace_id: 0,
    span_id: 0,
    trace_flags: 0,
    dropped_attributes_count: 0
  }

  defp init_state do
    {:ok, state} = Otel.Logs.LogRecordExporter.init(%{})
    state
  end

  defp configure_server(status_code) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    pid = spawn_link(fn -> accept_loop(listen, status_code) end)

    Application.put_env(:otel, :req_options, base_url: "http://localhost:#{port}")

    on_exit(fn ->
      Application.delete_env(:otel, :req_options)
      :gen_tcp.close(listen)
      ref = Process.monitor(pid)
      receive do: ({:DOWN, ^ref, _, _, _} -> :ok), after: (1_000 -> :ok)
    end)
  end

  defp accept_loop(listen, status_code) do
    case :gen_tcp.accept(listen, 1_000) do
      {:ok, socket} ->
        {:ok, _} = :gen_tcp.recv(socket, 0, 5_000)
        :gen_tcp.send(socket, "HTTP/1.1 #{status_code} OK\r\ncontent-length: 0\r\n\r\n")
        :gen_tcp.close(socket)
        accept_loop(listen, status_code)

      {:error, :timeout} ->
        accept_loop(listen, status_code)

      _ ->
        :ok
    end
  end

  describe "export/2" do
    test "empty list short-circuits to :ok" do
      assert :ok = Otel.Logs.LogRecordExporter.export([], init_state())
    end

    test "200 → :ok" do
      configure_server(200)
      assert :ok = Otel.Logs.LogRecordExporter.export([@log_record], init_state())
    end

    test "non-retryable 4xx → :error immediately" do
      configure_server(400)
      assert :error = Otel.Logs.LogRecordExporter.export([@log_record], init_state())
    end
  end

  test "shutdown/1 and force_flush/1 return :ok" do
    state = init_state()
    assert :ok = Otel.Logs.LogRecordExporter.shutdown(state)
    assert :ok = Otel.Logs.LogRecordExporter.force_flush(state)
  end
end
