defmodule Otel.Trace.SpanExporterTest do
  use ExUnit.Case, async: true

  @span %Otel.Trace.Span{
    trace_id: 1,
    span_id: 2,
    name: "test",
    kind: :internal,
    start_time: 1_000_000,
    end_time: 2_000_000,
    is_recording: false,
    tracestate: Otel.Trace.TraceState.new()
  }

  @resource Otel.Resource.create(%{"service.name" => "test"})

  defp init!(opts \\ %{}) do
    {:ok, state} = Otel.Trace.SpanExporter.init(opts)
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
    test "default appends /v1/traces" do
      assert init!().endpoint == "http://localhost:4318/v1/traces"
    end

    test "config :endpoint trims trailing slash and appends /v1/traces" do
      assert init!(%{endpoint: "http://custom:4318"}).endpoint == "http://custom:4318/v1/traces"
      assert init!(%{endpoint: "http://custom:4318/"}).endpoint == "http://custom:4318/v1/traces"
    end
  end

  describe "init/1 headers" do
    test "user-agent always included; config :headers map flow through" do
      headers = init!(%{headers: %{"key1" => "val1", "key2" => "val2"}}).headers

      assert {~c"key1", ~c"val1"} in headers
      assert {~c"key2", ~c"val2"} in headers
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
      assert init!(%{timeout: 5000}).timeout == 5000
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

  describe "init/1 retry_opts" do
    test "default %{}; stored from config" do
      assert init!().retry_opts == %{}
      assert init!(%{retry_opts: %{max_attempts: 7}}).retry_opts == %{max_attempts: 7}
    end
  end

  describe "export/3" do
    test "empty list short-circuits to :ok" do
      assert :ok = Otel.Trace.SpanExporter.export([], @resource, init!())
    end

    test "200 → :ok; gzip and ssl_options variants succeed" do
      ok = init!(%{endpoint: server(200)})
      assert :ok = Otel.Trace.SpanExporter.export([@span], @resource, ok)

      gz = init!(%{endpoint: server(200), compression: :gzip})
      assert :ok = Otel.Trace.SpanExporter.export([@span], @resource, gz)

      ssl = %{init!(%{endpoint: server(200)}) | ssl_options: [verify: :verify_none]}
      assert :ok = Otel.Trace.SpanExporter.export([@span], @resource, ssl)
    end

    test "503 retried then :error; 400 :error immediately" do
      retry =
        init!(%{
          endpoint: server(503),
          retry_opts: %{
            max_attempts: 2,
            initial_backoff_ms: 1,
            max_backoff_ms: 5,
            jitter_ratio: 0.0
          }
        })

      assert :error = Otel.Trace.SpanExporter.export([@span], @resource, retry)

      bad = init!(%{endpoint: server(400)})
      assert :error = Otel.Trace.SpanExporter.export([@span], @resource, bad)
    end
  end

  test "shutdown/1 returns :ok" do
    assert :ok = Otel.Trace.SpanExporter.shutdown(init!())
  end
end
