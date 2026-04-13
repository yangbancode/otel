defmodule Otel.Exporter.OTLP.TracesTest do
  use ExUnit.Case

  @test_span %Otel.SDK.Trace.Span{
    trace_id: 1,
    span_id: 2,
    name: "test",
    kind: :internal,
    start_time: 1_000_000,
    end_time: 2_000_000,
    is_recording: false,
    tracestate: %Otel.API.Trace.TraceState{}
  }

  @test_resource Otel.SDK.Resource.create(%{"service.name" => "test"})

  @env_vars [
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
    "OTEL_EXPORTER_OTLP_HEADERS",
    "OTEL_EXPORTER_OTLP_TRACES_HEADERS",
    "OTEL_EXPORTER_OTLP_COMPRESSION",
    "OTEL_EXPORTER_OTLP_TRACES_COMPRESSION",
    "OTEL_EXPORTER_OTLP_TIMEOUT",
    "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT"
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
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.endpoint == "http://localhost:4318/v1/traces"
      assert state.compression == :none
      assert state.timeout == 10_000
    end

    test "code config overrides defaults" do
      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{
          endpoint: "http://custom:4318",
          compression: :gzip,
          timeout: 5_000
        })

      assert state.endpoint == "http://custom:4318/v1/traces"
      assert state.compression == :gzip
      assert state.timeout == 5_000
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_ENDPOINT" do
    test "empty env var treated as unset" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.endpoint == "http://localhost:4318/v1/traces"
    end

    test "general endpoint env var appends /v1/traces" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://env-collector:4318")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.endpoint == "http://env-collector:4318/v1/traces"
    end

    test "general env var overrides code config" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://env:4318")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://code:4318"})
      assert state.endpoint == "http://env:4318/v1/traces"
    end

    test "signal-specific endpoint used as-is (no path appended)" do
      System.put_env("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://traces:4318/custom/path")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.endpoint == "http://traces:4318/custom/path"
    end

    test "signal-specific overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://general:4318")
      System.put_env("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://traces:4318/v1/traces")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.endpoint == "http://traces:4318/v1/traces"
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_HEADERS" do
    test "general headers env var" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "key1=val1,key2=val2")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert {~c"key1", ~c"val1"} in state.headers
      assert {~c"key2", ~c"val2"} in state.headers
    end

    test "signal-specific headers override general" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "general=yes")
      System.put_env("OTEL_EXPORTER_OTLP_TRACES_HEADERS", "traces=yes")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert {~c"traces", ~c"yes"} in state.headers
      refute Enum.any?(state.headers, fn {k, _} -> k == ~c"general" end)
    end

    test "env headers override code config headers" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "env=yes")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{headers: %{"code" => "yes"}})
      assert {~c"env", ~c"yes"} in state.headers
      refute Enum.any?(state.headers, fn {k, _} -> k == ~c"code" end)
    end

    test "always includes user-agent" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "custom=val")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert Enum.any?(state.headers, fn {k, _} -> k == ~c"user-agent" end)
    end

    test "skips invalid header pairs" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "valid=yes,=invalid,also=ok")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert {~c"valid", ~c"yes"} in state.headers
      assert {~c"also", ~c"ok"} in state.headers
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_COMPRESSION" do
    test "general compression env var" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.compression == :gzip
    end

    test "signal-specific compression overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      System.put_env("OTEL_EXPORTER_OTLP_TRACES_COMPRESSION", "none")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.compression == :none
    end

    test "unknown compression value defaults to none" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "unknown")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.compression == :none
    end

    test "env compression overrides code config" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{compression: :none})
      assert state.compression == :gzip
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_TIMEOUT" do
    test "general timeout env var" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "5000")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.timeout == 5000
    end

    test "signal-specific timeout overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "5000")
      System.put_env("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "3000")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.timeout == 3000
    end

    test "unparseable timeout uses default" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "not_a_number")
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.timeout == 10_000
    end
  end

  describe "init/1 SSL" do
    test "http endpoint has empty ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.ssl_options == []
    end

    test "https endpoint gets default ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "https://collector:4318"})
      assert state.ssl_options[:verify] == :verify_peer
    end

    test "custom ssl_options override defaults" do
      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{
          endpoint: "https://collector:4318",
          ssl_options: [verify: :verify_none]
        })

      assert state.ssl_options == [verify: :verify_none]
    end
  end

  describe "export/3 success" do
    test "returns :ok for empty span list" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert Otel.Exporter.OTLP.Traces.export([], @test_resource, state) == :ok
    end

    test "returns :ok when server responds 200" do
      {pid, port, listen} = start_test_server(200)
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:#{port}"})
      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :ok
      stop_test_server(pid, listen)
    end

    test "returns :ok with gzip compression" do
      {pid, port, listen} = start_test_server(200)

      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{
          endpoint: "http://localhost:#{port}",
          compression: :gzip
        })

      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :ok
      stop_test_server(pid, listen)
    end

    test "returns :ok with ssl_options set" do
      {pid, port, listen} = start_test_server(200)
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:#{port}"})
      state = %{state | ssl_options: [verify: :verify_none]}
      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :ok
      stop_test_server(pid, listen)
    end
  end

  describe "export/3 errors" do
    test "returns :error when endpoint unreachable" do
      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:19999", timeout: 500})

      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :error
    end

    test "returns :error for 400 Bad Request" do
      {pid, port, listen} = start_test_server(400)
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:#{port}"})
      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :error
      stop_test_server(pid, listen)
    end

    test "returns :error for 500 Internal Server Error" do
      {pid, port, listen} = start_test_server(500)
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:#{port}"})
      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :error
      stop_test_server(pid, listen)
    end

    test "returns :error for 503 Service Unavailable" do
      {pid, port, listen} = start_test_server(503)
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:#{port}"})
      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :error
      stop_test_server(pid, listen)
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert Otel.Exporter.OTLP.Traces.shutdown(state) == :ok
    end
  end
end
