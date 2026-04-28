defmodule Otel.OTLP.Logs.LogRecordExporter.HTTPTest do
  use ExUnit.Case, async: false

  @resource Otel.SDK.Resource.create(%{"service.name" => "test"})

  @log_record %Otel.SDK.Logs.LogRecord{
    body: "test log message",
    severity_number: 9,
    severity_text: "INFO",
    timestamp: 1_000_000,
    observed_timestamp: 2_000_000,
    attributes: %{"key" => "value"},
    event_name: "",
    scope: %Otel.API.InstrumentationScope{name: "test_lib"},
    resource: @resource,
    trace_id: 0,
    span_id: 0,
    trace_flags: 0,
    dropped_attributes_count: 0
  }

  @env_vars [
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT",
    "OTEL_EXPORTER_OTLP_HEADERS",
    "OTEL_EXPORTER_OTLP_LOGS_HEADERS",
    "OTEL_EXPORTER_OTLP_COMPRESSION",
    "OTEL_EXPORTER_OTLP_LOGS_COMPRESSION",
    "OTEL_EXPORTER_OTLP_TIMEOUT",
    "OTEL_EXPORTER_OTLP_LOGS_TIMEOUT"
  ]

  setup do
    Enum.each(@env_vars, &System.delete_env/1)
    on_exit(fn -> Enum.each(@env_vars, &System.delete_env/1) end)
    :ok
  end

  defp init!(opts \\ %{}) do
    {:ok, state} = Otel.OTLP.Logs.LogRecordExporter.HTTP.init(opts)
    state
  end

  defp put_env(pairs), do: Enum.each(pairs, fn {k, v} -> System.put_env(k, v) end)

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
    test "default and code-config both append /v1/logs" do
      assert init!().endpoint == "http://localhost:4318/v1/logs"
      assert init!(%{endpoint: "http://custom:4318"}).endpoint == "http://custom:4318/v1/logs"
    end

    test "general env appends /v1/logs and overrides code config" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://env:4318")
      assert init!(%{endpoint: "http://code:4318"}).endpoint == "http://env:4318/v1/logs"
    end

    test "signal-specific env used as-is; overrides general" do
      put_env([
        {"OTEL_EXPORTER_OTLP_ENDPOINT", "http://general:4318"},
        {"OTEL_EXPORTER_OTLP_LOGS_ENDPOINT", "http://logs:4318/custom"}
      ])

      assert init!().endpoint == "http://logs:4318/custom"
    end

    test "empty env var treated as unset" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT", "")
      assert init!().endpoint == "http://localhost:4318/v1/logs"
    end
  end

  describe "init/1 headers" do
    test "general env parsed; user-agent always included" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "key1=val1,key2=val2")
      headers = init!().headers

      assert {~c"key1", ~c"val1"} in headers
      assert {~c"key2", ~c"val2"} in headers
      assert Enum.any?(headers, fn {k, _} -> k == ~c"user-agent" end)
    end

    test "signal-specific overrides general; env overrides code" do
      put_env([
        {"OTEL_EXPORTER_OTLP_HEADERS", "general=yes"},
        {"OTEL_EXPORTER_OTLP_LOGS_HEADERS", "logs=yes"}
      ])

      headers = init!(%{headers: %{"code" => "yes"}}).headers
      assert {~c"logs", ~c"yes"} in headers
      refute Enum.any?(headers, fn {k, _} -> k in [~c"general", ~c"code"] end)
    end

    test "code config used when no env set" do
      assert {~c"auth", ~c"token"} in init!(%{headers: %{"auth" => "token"}}).headers
    end

    test "skips invalid pairs" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_HEADERS", "valid=yes,=invalid")
      assert {~c"valid", ~c"yes"} in init!().headers
    end
  end

  describe "init/1 compression" do
    test "general env" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      assert init!().compression == :gzip
    end

    test "signal-specific overrides general" do
      put_env([
        {"OTEL_EXPORTER_OTLP_COMPRESSION", "gzip"},
        {"OTEL_EXPORTER_OTLP_LOGS_COMPRESSION", "none"}
      ])

      assert init!().compression == :none
    end

    test "unknown value defaults to none" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_COMPRESSION", "brotli")
      assert init!().compression == :none
    end
  end

  describe "init/1 timeout" do
    test "general env; signal-specific overrides" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "5000")
      assert init!().timeout == 5000

      System.put_env("OTEL_EXPORTER_OTLP_LOGS_TIMEOUT", "3000")
      assert init!().timeout == 3000
    end

    test "unparseable falls back to default" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_TIMEOUT", "abc")
      assert init!().timeout == 10_000
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
      assert :ok = Otel.OTLP.Logs.LogRecordExporter.HTTP.export([], init!())
    end

    test "200 → :ok; gzip and ssl_options variants succeed" do
      ok = init!(%{endpoint: server(200)})
      assert :ok = Otel.OTLP.Logs.LogRecordExporter.HTTP.export([@log_record], ok)

      gz = init!(%{endpoint: server(200), compression: :gzip})
      assert :ok = Otel.OTLP.Logs.LogRecordExporter.HTTP.export([@log_record], gz)

      ssl = %{init!(%{endpoint: server(200)}) | ssl_options: [verify: :verify_none]}
      assert :ok = Otel.OTLP.Logs.LogRecordExporter.HTTP.export([@log_record], ssl)
    end

    test "503 retried then :error" do
      state =
        init!(%{
          endpoint: server(503),
          retry_opts: %{
            max_attempts: 2,
            initial_backoff_ms: 1,
            max_backoff_ms: 5,
            jitter_ratio: 0.0
          }
        })

      assert :error = Otel.OTLP.Logs.LogRecordExporter.HTTP.export([@log_record], state)
    end
  end

  test "shutdown/1 and force_flush/1 return :ok" do
    state = init!()
    assert :ok = Otel.OTLP.Logs.LogRecordExporter.HTTP.shutdown(state)
    assert :ok = Otel.OTLP.Logs.LogRecordExporter.HTTP.force_flush(state)
  end
end
