defmodule Otel.Exporter.OTLP.MetricsTest do
  use ExUnit.Case

  @test_resource Otel.SDK.Resource.create(%{"service.name" => "test"})

  @test_metric %{
    name: "http.requests",
    description: "Number of HTTP requests",
    unit: "1",
    scope: %Otel.API.InstrumentationScope{name: "test_lib"},
    resource: @test_resource,
    kind: :counter,
    temporality: :cumulative,
    is_monotonic: true,
    datapoints: [
      %{
        attributes: %{method: "GET"},
        value: 42,
        start_time: 1_000_000,
        time: 2_000_000,
        exemplars: []
      }
    ]
  }

  @env_vars [
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT",
    "OTEL_EXPORTER_OTLP_HEADERS",
    "OTEL_EXPORTER_OTLP_METRICS_HEADERS",
    "OTEL_EXPORTER_OTLP_COMPRESSION",
    "OTEL_EXPORTER_OTLP_METRICS_COMPRESSION",
    "OTEL_EXPORTER_OTLP_TIMEOUT",
    "OTEL_EXPORTER_OTLP_METRICS_TIMEOUT"
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
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.endpoint == "http://localhost:4318/v1/metrics"
      assert state.compression == :none
      assert state.timeout == 10_000
    end

    test "code config overrides defaults" do
      {:ok, state} =
        Otel.Exporter.OTLP.Metrics.init(%{
          endpoint: "http://custom:4318",
          compression: :gzip,
          timeout: 5_000
        })

      assert state.endpoint == "http://custom:4318/v1/metrics"
      assert state.compression == :gzip
      assert state.timeout == 5_000
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_METRICS_ENDPOINT" do
    test "general endpoint env var appends /v1/metrics" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://env-collector:4318")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.endpoint == "http://env-collector:4318/v1/metrics"
    end

    test "signal-specific endpoint used as-is" do
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "http://metrics:4318/custom")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.endpoint == "http://metrics:4318/custom"
    end

    test "signal-specific overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://general:4318")
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "http://metrics:4318/v1/metrics")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.endpoint == "http://metrics:4318/v1/metrics"
    end

    test "general endpoint with trailing slash" do
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4318/")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.endpoint == "http://collector:4318/v1/metrics"
    end

    test "empty signal env falls through to general" do
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "")
      System.put_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://general:4318")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.endpoint == "http://general:4318/v1/metrics"
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_METRICS_HEADERS" do
    test "signal-specific headers override general" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "general=yes")
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_HEADERS", "metrics=yes")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert {~c"metrics", ~c"yes"} in state.headers
      refute Enum.any?(state.headers, fn {k, _} -> k == ~c"general" end)
    end

    test "always includes user-agent" do
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert Enum.any?(state.headers, fn {k, _} -> k == ~c"user-agent" end)
    end

    test "general headers env var" do
      System.put_env("OTEL_EXPORTER_OTLP_HEADERS", "key1=val1,key2=val2")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert {~c"key1", ~c"val1"} in state.headers
    end

    test "skips invalid header pairs" do
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_HEADERS", "valid=yes,=invalid")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert {~c"valid", ~c"yes"} in state.headers
    end

    test "code config headers as map" do
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{headers: %{"auth" => "token"}})
      assert {~c"auth", ~c"token"} in state.headers
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_METRICS_COMPRESSION" do
    test "signal-specific compression overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_COMPRESSION", "none")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.compression == :none
    end

    test "general compression env var" do
      System.put_env("OTEL_EXPORTER_OTLP_COMPRESSION", "gzip")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.compression == :gzip
    end

    test "unknown compression defaults to none" do
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_COMPRESSION", "brotli")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.compression == :none
    end
  end

  describe "init/1 OTEL_EXPORTER_OTLP_METRICS_TIMEOUT" do
    test "signal-specific timeout overrides general" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "5000")
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_TIMEOUT", "3000")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.timeout == 3000
    end

    test "general timeout env var" do
      System.put_env("OTEL_EXPORTER_OTLP_TIMEOUT", "7000")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.timeout == 7000
    end

    test "unparseable timeout uses default" do
      System.put_env("OTEL_EXPORTER_OTLP_METRICS_TIMEOUT", "abc")
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.timeout == 10_000
    end
  end

  describe "init/1 SSL" do
    test "http endpoint has empty ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert state.ssl_options == []
    end

    test "https endpoint gets default ssl_options" do
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{endpoint: "https://collector:4318"})
      assert state.ssl_options[:verify] == :verify_peer
    end

    test "custom ssl_options override defaults" do
      {:ok, state} =
        Otel.Exporter.OTLP.Metrics.init(%{
          endpoint: "https://collector:4318",
          ssl_options: [verify: :verify_none]
        })

      assert state.ssl_options == [verify: :verify_none]
    end
  end

  describe "export/2 success" do
    test "returns :ok for empty metrics list" do
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert Otel.Exporter.OTLP.Metrics.export([], state) == :ok
    end

    test "returns :ok when server responds 200" do
      {pid, port, listen} = start_test_server(200)
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{endpoint: "http://localhost:#{port}"})
      assert Otel.Exporter.OTLP.Metrics.export([@test_metric], state) == :ok
      stop_test_server(pid, listen)
    end

    test "returns :ok with gzip compression" do
      {pid, port, listen} = start_test_server(200)

      {:ok, state} =
        Otel.Exporter.OTLP.Metrics.init(%{
          endpoint: "http://localhost:#{port}",
          compression: :gzip
        })

      assert Otel.Exporter.OTLP.Metrics.export([@test_metric], state) == :ok
      stop_test_server(pid, listen)
    end

    test "returns :ok with ssl_options set" do
      {pid, port, listen} = start_test_server(200)
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{endpoint: "http://localhost:#{port}"})
      state = %{state | ssl_options: [verify: :verify_none]}
      assert Otel.Exporter.OTLP.Metrics.export([@test_metric], state) == :ok
      stop_test_server(pid, listen)
    end
  end

  describe "export/2 errors" do
    test "returns :error when endpoint unreachable" do
      {:ok, state} =
        Otel.Exporter.OTLP.Metrics.init(%{endpoint: "http://localhost:19999", timeout: 500})

      assert Otel.Exporter.OTLP.Metrics.export([@test_metric], state) == :error
    end

    test "returns :error for 500 status" do
      {pid, port, listen} = start_test_server(500)
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{endpoint: "http://localhost:#{port}"})
      assert Otel.Exporter.OTLP.Metrics.export([@test_metric], state) == :error
      stop_test_server(pid, listen)
    end
  end

  describe "force_flush/1 and shutdown/1" do
    test "force_flush returns :ok" do
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert Otel.Exporter.OTLP.Metrics.force_flush(state) == :ok
    end

    test "shutdown returns :ok" do
      {:ok, state} = Otel.Exporter.OTLP.Metrics.init(%{})
      assert Otel.Exporter.OTLP.Metrics.shutdown(state) == :ok
    end
  end
end
