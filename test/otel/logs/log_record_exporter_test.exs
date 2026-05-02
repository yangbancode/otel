defmodule Otel.Logs.LogRecordExporterTest do
  use ExUnit.Case, async: true

  @resource Otel.Resource.create(%{"service.name" => "test"})

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

  defp init!(opts \\ %{}) do
    {:ok, state} = Otel.Logs.LogRecordExporter.init(opts)
    state
  end

  defp server(status_code) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    pid = spawn_link(fn -> accept_loop(listen, status_code) end)

    on_exit(fn ->
      :gen_tcp.close(listen)
      ref = Process.monitor(pid)
      receive do: ({:DOWN, ^ref, _, _, _} -> :ok), after: (1000 -> :ok)
    end)

    "http://localhost:#{port}"
  end

  defp accept_loop(listen, status_code) do
    case :gen_tcp.accept(listen, 1000) do
      {:ok, socket} ->
        {:ok, _} = :gen_tcp.recv(socket, 0, 5000)
        :gen_tcp.send(socket, "HTTP/1.1 #{status_code} OK\r\ncontent-length: 0\r\n\r\n")
        :gen_tcp.close(socket)
        accept_loop(listen, status_code)

      {:error, :timeout} ->
        accept_loop(listen, status_code)

      _ ->
        :ok
    end
  end

  describe "init/1 endpoint" do
    test "default appends /v1/logs" do
      assert init!().endpoint == "http://localhost:4318/v1/logs"
    end

    test "config :endpoint trims trailing slash and appends /v1/logs" do
      assert init!(%{endpoint: "http://custom:4318"}).endpoint == "http://custom:4318/v1/logs"
      assert init!(%{endpoint: "http://custom:4318/"}).endpoint == "http://custom:4318/v1/logs"
    end
  end

  describe "init/1 headers" do
    test "user-agent always included; config :headers map flow through" do
      headers = init!(%{headers: %{"key1" => "val1", "auth" => "token"}}).headers

      assert {~c"key1", ~c"val1"} in headers
      assert {~c"auth", ~c"token"} in headers
      assert Enum.any?(headers, fn {k, _} -> k == ~c"user-agent" end)
    end

    test "empty headers map → only user-agent" do
      headers = init!().headers
      assert [{~c"user-agent", _}] = headers
    end
  end

  describe "init/1 compression" do
    test "default :none; explicit :gzip flows through" do
      assert init!().compression == :none
      assert init!(%{compression: :gzip}).compression == :gzip
    end
  end

  describe "init/1 timeout" do
    test "default 10_000ms; explicit value flows through" do
      assert init!().timeout == 10_000
      assert init!(%{timeout: 3000}).timeout == 3000
    end
  end

  describe "init/1 ssl_options" do
    test "http→empty; https→verify_peer; custom override" do
      assert init!().ssl_options == []
      assert init!(%{endpoint: "https://collector:4318"}).ssl_options[:verify] == :verify_peer

      assert init!(%{
               endpoint: "https://collector:4318",
               ssl_options: [verify: :verify_none]
             }).ssl_options == [verify: :verify_none]
    end
  end

  describe "export/2" do
    test "empty list short-circuits to :ok" do
      assert :ok = Otel.Logs.LogRecordExporter.export([], init!())
    end

    test "200 → :ok; gzip and ssl_options variants succeed" do
      ok = init!(%{endpoint: server(200)})
      assert :ok = Otel.Logs.LogRecordExporter.export([@log_record], ok)

      gz = init!(%{endpoint: server(200), compression: :gzip})
      assert :ok = Otel.Logs.LogRecordExporter.export([@log_record], gz)

      ssl = %{init!(%{endpoint: server(200)}) | ssl_options: [verify: :verify_none]}
      assert :ok = Otel.Logs.LogRecordExporter.export([@log_record], ssl)
    end

    # Retry behavior is exercised comprehensively by
    # `Otel.OTLP.HTTP.RetryTest`. The exporter delegates verbatim
    # to that module with hardcoded Java OTLP defaults.
    test "non-retryable 4xx → :error immediately" do
      bad = init!(%{endpoint: server(400)})
      assert :error = Otel.Logs.LogRecordExporter.export([@log_record], bad)
    end
  end

  test "shutdown/1 and force_flush/1 return :ok" do
    state = init!()
    assert :ok = Otel.Logs.LogRecordExporter.shutdown(state)
    assert :ok = Otel.Logs.LogRecordExporter.force_flush(state)
  end
end
