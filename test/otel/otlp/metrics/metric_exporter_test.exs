defmodule Otel.Metrics.MetricExporterTest do
  # async: false — mutates `:otel` Application env (`:req_options`).
  use ExUnit.Case, async: false

  @resource %Otel.Resource{attributes: %{"service.name" => "test"}}

  @metric %{
    name: "http.requests",
    description: "Number of HTTP requests",
    unit: "1",
    scope: %Otel.InstrumentationScope{name: "test_lib"},
    resource: @resource,
    kind: :counter,
    temporality: :cumulative,
    is_monotonic: true,
    datapoints: [
      %{
        attributes: %{"method" => "GET"},
        value: 42,
        start_time: 1_000_000,
        time: 2_000_000,
        exemplars: []
      }
    ]
  }

  defp init_state do
    {:ok, state} = Otel.Metrics.MetricExporter.init(%{})
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
      assert :ok = Otel.Metrics.MetricExporter.export([], init_state())
    end

    test "200 → :ok" do
      configure_server(200)
      assert :ok = Otel.Metrics.MetricExporter.export([@metric], init_state())
    end

    test "non-retryable 4xx → :error immediately" do
      configure_server(400)
      assert :error = Otel.Metrics.MetricExporter.export([@metric], init_state())
    end
  end

  test "shutdown/1 and force_flush/1 return :ok" do
    state = init_state()
    assert :ok = Otel.Metrics.MetricExporter.shutdown(state)
    assert :ok = Otel.Metrics.MetricExporter.force_flush(state)
  end
end
