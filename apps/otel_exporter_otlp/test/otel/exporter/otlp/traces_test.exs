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

  defp start_test_server do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    pid =
      spawn_link(fn ->
        accept_loop(listen)
      end)

    {pid, port, listen}
  end

  defp accept_loop(listen) do
    case :gen_tcp.accept(listen, 1000) do
      {:ok, socket} ->
        read_request(socket)
        response = "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"
        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        accept_loop(listen)

      {:error, :timeout} ->
        accept_loop(listen)

      _ ->
        :ok
    end
  end

  defp read_request(socket) do
    {:ok, _data} = :gen_tcp.recv(socket, 0, 5000)
  end

  defp stop_test_server(listen) do
    :gen_tcp.close(listen)
  end

  describe "init/1" do
    test "returns state with default endpoint" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.endpoint == "http://localhost:4318/v1/traces"
      assert state.compression == :none
      assert state.timeout == 10_000
    end

    test "custom endpoint" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://collector:4318"})
      assert state.endpoint == "http://collector:4318/v1/traces"
    end

    test "strips trailing slash from endpoint" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://collector:4318/"})
      assert state.endpoint == "http://collector:4318/v1/traces"
    end

    test "gzip compression" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{compression: :gzip})
      assert state.compression == :gzip
    end

    test "custom timeout" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{timeout: 5_000})
      assert state.timeout == 5_000
    end

    test "custom headers" do
      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{headers: %{"Authorization" => "Bearer token"}})

      assert {~c"Authorization", ~c"Bearer token"} in state.headers
    end

    test "includes user-agent header" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert Enum.any?(state.headers, fn {k, _v} -> k == ~c"user-agent" end)
    end

    test "http endpoint has empty ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert state.ssl_options == []
    end

    test "https endpoint gets default ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{endpoint: "https://collector:4318"})
      assert state.ssl_options[:verify] == :verify_peer
      assert is_list(state.ssl_options[:cacerts])
      assert state.ssl_options[:server_name_indication] == ~c"collector"
    end

    test "custom ssl_options override defaults" do
      custom_opts = [verify: :verify_none]

      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{
          endpoint: "https://collector:4318",
          ssl_options: custom_opts
        })

      assert state.ssl_options == custom_opts
    end
  end

  describe "export/3" do
    test "returns :ok for empty span list" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert Otel.Exporter.OTLP.Traces.export([], @test_resource, state) == :ok
    end

    test "returns :ok when server responds 200" do
      {_pid, port, listen} = start_test_server()

      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:#{port}"})

      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :ok

      stop_test_server(listen)
    end

    test "returns :ok with gzip compression" do
      {_pid, port, listen} = start_test_server()

      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{
          endpoint: "http://localhost:#{port}",
          compression: :gzip
        })

      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :ok

      stop_test_server(listen)
    end

    test "returns :error when endpoint unreachable" do
      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:19999", timeout: 500})

      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :error
    end

    test "returns :ok with ssl_options set" do
      {_pid, port, listen} = start_test_server()

      # Use HTTP server but with non-empty ssl_options to exercise the ssl path in build_http_options
      # httpc ignores ssl options for http:// URLs so this is safe
      {:ok, state} =
        Otel.Exporter.OTLP.Traces.init(%{endpoint: "http://localhost:#{port}"})

      state = %{state | ssl_options: [verify: :verify_none]}

      assert Otel.Exporter.OTLP.Traces.export([@test_span], @test_resource, state) == :ok

      stop_test_server(listen)
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      {:ok, state} = Otel.Exporter.OTLP.Traces.init(%{})
      assert Otel.Exporter.OTLP.Traces.shutdown(state) == :ok
    end
  end
end
