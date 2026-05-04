defmodule Otel.Trace.SpanExporterTest do
  # async: false — mutates `:otel` Application env (`:exporter`)
  # and shares the global `SpanStorage` ETS table.
  use ExUnit.Case, async: false

  @span %Otel.Trace.Span{
    trace_id: 1,
    span_id: 0xFF00000000000099,
    name: "test",
    kind: :internal,
    start_time: 1_000_000,
    end_time: 2_000_000,
    is_recording: false,
    tracestate: Otel.Trace.TraceState.new(),
    instrumentation_scope: %Otel.InstrumentationScope{}
  }

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.delete_env(:otel, :exporter)
      Application.stop(:otel)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  describe "force_flush/1" do
    test "empty storage → :ok (no HTTP request sent)" do
      start_server_and_configure(200)

      assert :ok = Otel.Trace.SpanExporter.force_flush()
      refute_receive :request_received, 200
    end

    test "completed spans → drain + HTTP POST + storage emptied" do
      start_server_and_configure(200)

      Otel.Trace.SpanStorage.insert_active(@span)
      Otel.Trace.SpanStorage.mark_completed(@span.span_id, 2_000_000)

      assert :ok = Otel.Trace.SpanExporter.force_flush()
      assert_receive :request_received, 5_000
      assert [] = Otel.Trace.SpanStorage.take_completed(10)
    end

    test "active (not yet completed) spans are not exported" do
      start_server_and_configure(200)

      Otel.Trace.SpanStorage.insert_active(@span)
      # No mark_completed — span is still :active

      assert :ok = Otel.Trace.SpanExporter.force_flush()
      refute_receive :request_received, 200

      # Active span untouched
      assert %Otel.Trace.Span{} = Otel.Trace.SpanStorage.get_active(@span.span_id)
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

    Application.put_env(:otel, :exporter, %{endpoint: "http://localhost:#{port}"})
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
