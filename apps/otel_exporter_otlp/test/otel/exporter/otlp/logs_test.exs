defmodule Otel.Exporter.OTLP.LogsTest do
  use ExUnit.Case

  @test_resource Otel.SDK.Resource.create(%{"service.name" => "test"})

  @test_log_record %{
    body: "test log message",
    severity_number: 9,
    severity_text: "INFO",
    timestamp: 1_000_000,
    observed_timestamp: 2_000_000,
    attributes: %{key: "value"},
    event_name: nil,
    scope: %Otel.API.InstrumentationScope{name: "test_lib"},
    resource: @test_resource,
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

  defp start_test_server(status_code) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    pid =
      spawn_link(fn ->
        accept_loop(listen, status_code)
      end)

    {pid, port, listen}
  end

  defp accept_loop(listen, status_code) do
    case :gen_tcp.accept(listen, 1000) do
      {:ok, socket} ->
        {:ok, _data} = :gen_tcp.recv(socket, 0, 5000)
        response = "HTTP/1.1 #{status_code} OK\r\ncontent-length: 0\r\n\r\n"
        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        accept_loop(listen, status_code)

      {:error, :timeout} ->
        accept_loop(listen, status_code)

      _ ->
        :ok
    end
  end

  defp stop_test_server(pid, listen) do
    :gen_tcp.close(listen)
    ref = Process.monitor(pid)
    receive do: ({:DOWN, ^ref, _, _, _} -> :ok), after: (1000 -> :ok)
  end

  describe "init/1 defaults" do
    test "returns state with default values" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.endpoint == "http://localhost:4318/v1/logs"
      assert state.compression == :none
      assert state.timeout == 10_000
    end
  end

  describe "init/1 endpoint" do
    test "general endpoint appends /v1/logs" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4318")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.endpoint == "http://collector:4318/v1/logs"
    end

    test "signal-specific endpoint used as-is" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT", "http://logs:4318/custom")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.endpoint == "http://logs:4318/custom"
    end

    test "signal-specific overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://general:4318")
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT", "http://logs:4318/v1/logs")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.endpoint == "http://logs:4318/v1/logs"
    end

    test "empty env var treated as unset" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT", "")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.endpoint == "http://localhost:4318/v1/logs"
    end

    test "code config overrides defaults" do
      {:ok, state} =
        Otel.Exporter.OTLP.Logs.init(%{
          endpoint: "http://custom:4318",
          compression: :gzip,
          timeout: 5_000
        })

      assert state.endpoint == "http://custom:4318/v1/logs"
      assert state.compression == :gzip
      assert state.timeout == 5_000
    end

    test "general env overrides code config" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://env:4318")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{endpoint: "http://code:4318"})
      assert state.endpoint == "http://env:4318/v1/logs"
    end
  end

  describe "init/1 headers" do
    test "general headers env var" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "key1=val1,key2=val2")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert {~c"key1", ~c"val1"} in state.headers
      assert {~c"key2", ~c"val2"} in state.headers
    end

    test "signal-specific headers override general" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "general=yes")
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_HEADERS", "logs=yes")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert {~c"logs", ~c"yes"} in state.headers
      refute Enum.any?(state.headers, fn {k, _} -> k == ~c"general" end)
    end

    test "always includes user-agent" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert Enum.any?(state.headers, fn {k, _} -> k == ~c"user-agent" end)
    end

    test "skips invalid header pairs" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_HEADERS", "valid=yes,=invalid")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert {~c"valid", ~c"yes"} in state.headers
    end

    test "code config headers as map" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{headers: %{"auth" => "token"}})
      assert {~c"auth", ~c"token"} in state.headers
    end
  end

  describe "init/1 compression" do
    test "general compression env var" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.compression == :gzip
    end

    test "signal-specific compression overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_COMPRESSION", "none")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.compression == :none
    end

    test "unknown compression defaults to none" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_COMPRESSION", "brotli")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.compression == :none
    end
  end

  describe "init/1 timeout" do
    test "general timeout env var" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "5000")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.timeout == 5000
    end

    test "signal-specific timeout overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "5000")
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_TIMEOUT", "3000")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.timeout == 3000
    end

    test "unparseable timeout uses default" do
      System.put_env("OTEL_EXPORTER_OTLP_LOGS_TIMEOUT", "abc")
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.timeout == 10_000
    end
  end

  describe "init/1 SSL" do
    test "http endpoint has empty ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert state.ssl_options == []
    end

    test "https endpoint gets default ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{endpoint: "https://collector:4318"})
      assert state.ssl_options[:verify] == :verify_peer
    end

    test "custom ssl_options override defaults" do
      {:ok, state} =
        Otel.Exporter.OTLP.Logs.init(%{
          endpoint: "https://collector:4318",
          ssl_options: [verify: :verify_none]
        })

      assert state.ssl_options == [verify: :verify_none]
    end
  end

  describe "export/2" do
    test "returns :ok for empty list" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert :ok == Otel.Exporter.OTLP.Logs.export([], state)
    end

    test "returns :ok when server responds 200" do
      {pid, port, listen} = start_test_server(200)
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{endpoint: "http://localhost:#{port}"})
      assert :ok == Otel.Exporter.OTLP.Logs.export([@test_log_record], state)
      stop_test_server(pid, listen)
    end

    test "returns :ok with gzip compression" do
      {pid, port, listen} = start_test_server(200)

      {:ok, state} =
        Otel.Exporter.OTLP.Logs.init(%{
          endpoint: "http://localhost:#{port}",
          compression: :gzip
        })

      assert :ok == Otel.Exporter.OTLP.Logs.export([@test_log_record], state)
      stop_test_server(pid, listen)
    end

    test "returns :error when endpoint unreachable" do
      {:ok, state} =
        Otel.Exporter.OTLP.Logs.init(%{endpoint: "http://localhost:19999", timeout: 500})

      assert :error == Otel.Exporter.OTLP.Logs.export([@test_log_record], state)
    end

    test "returns :error for 500 status" do
      {pid, port, listen} = start_test_server(500)
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{endpoint: "http://localhost:#{port}"})
      assert :error == Otel.Exporter.OTLP.Logs.export([@test_log_record], state)
      stop_test_server(pid, listen)
    end
  end

  describe "shutdown/1 and force_flush/1" do
    test "shutdown returns :ok" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert :ok == Otel.Exporter.OTLP.Logs.shutdown(state)
    end

    test "force_flush returns :ok" do
      {:ok, state} = Otel.Exporter.OTLP.Logs.init(%{})
      assert :ok == Otel.Exporter.OTLP.Logs.force_flush(state)
    end
  end
end
