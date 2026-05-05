defmodule Otel.Metrics.MetricExporterTest do
  # async: false — mutates `:otel` Application env
  # (`:req_options`) and shares the global metrics ETS tables.
  use ExUnit.Case, async: false

  defp restart_sdk(env), do: Otel.TestSupport.restart_with(env)
  defp meter_config, do: Otel.Metrics.meter_config()

  setup do
    restart_sdk(metrics: [readers: []])
    %{config: meter_config()}
  end

  describe "collect/1 — instrument kinds" do
    test "no instruments → []", %{config: config} do
      assert [] = Otel.Metrics.MetricExporter.collect(config)
    end

    test "counter accumulates per attribute set; metric carries name/unit/kind/scope/resource",
         %{config: config} do
      counter = Otel.Metrics.Meter.create_counter("requests", unit: "1")
      Otel.Metrics.Meter.record(counter, 5, %{"method" => "GET"})
      Otel.Metrics.Meter.record(counter, 3, %{"method" => "GET"})

      [metric] = Otel.Metrics.MetricExporter.collect(config)

      assert metric.name == "requests"
      assert metric.unit == "1"
      assert metric.kind == :counter
      assert metric.scope.name == "otel"
      assert %Otel.Resource{} = metric.resource

      [dp] = metric.datapoints
      assert dp.value == 8
      assert dp.attributes == %{"method" => "GET"}
    end

    test "histogram aggregates count + sum; observable callback feeds gauge value",
         %{config: config} do
      hist = Otel.Metrics.Meter.create_histogram("latency", unit: "ms")
      Otel.Metrics.Meter.record(hist, 50, %{})
      Otel.Metrics.Meter.record(hist, 150, %{})

      cb = fn _ -> [%Otel.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}] end
      Otel.Metrics.Meter.create_observable_gauge("cpu", cb, nil, [])

      metrics = Otel.Metrics.MetricExporter.collect(config)
      by_name = Map.new(metrics, &{&1.name, &1})

      assert [%{value: %{count: 2, sum: 200}}] = by_name["latency"].datapoints
      assert [%{value: 42}] = by_name["cpu"].datapoints
    end

    test "sync + async + multiple instruments collect in one pass",
         %{config: config} do
      counter = Otel.Metrics.Meter.create_counter("req", [])
      gauge = Otel.Metrics.Meter.create_gauge("temp", [])
      Otel.Metrics.Meter.record(counter, 1, %{})
      Otel.Metrics.Meter.record(gauge, 22, %{})

      names = Otel.Metrics.MetricExporter.collect(config) |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["req", "temp"]
    end
  end

  # Spec metrics/sdk.md L1374-L1389 — exemplar_filter (:always_on /
  # :always_off / :trace_based) gates whether reservoirs collect at
  # all; reservoirs reset between collect calls. The SDK hardcodes
  # `:trace_based`; tests exercise the other branches by patching
  # the filter directly onto `instrument.config` (used by `record`)
  # and onto the collect-side config map.
  describe "collect/1 — exemplars" do
    test ":always_on collects exemplars; :always_off yields []" do
      restart_sdk(metrics: [readers: []])

      config = %{meter_config() | exemplar_filter: :always_on}
      counter = override_filter(Otel.Metrics.Meter.create_counter("sampled", []), :always_on)
      Otel.Metrics.Meter.record(counter, 42, %{"method" => "GET"})

      [%{datapoints: [dp]}] = Otel.Metrics.MetricExporter.collect(config)
      assert hd(dp.exemplars).value == 42

      restart_sdk(metrics: [readers: []])
      config2 = %{meter_config() | exemplar_filter: :always_off}

      counter2 =
        override_filter(Otel.Metrics.Meter.create_counter("not_sampled", []), :always_off)

      Otel.Metrics.Meter.record(counter2, 1, %{})

      [%{datapoints: [dp2]}] = Otel.Metrics.MetricExporter.collect(config2)
      assert dp2.exemplars == []
    end

    test "reservoirs reset between collect calls" do
      restart_sdk(metrics: [readers: []])
      config = %{meter_config() | exemplar_filter: :always_on}
      counter = override_filter(Otel.Metrics.Meter.create_counter("reset_test", []), :always_on)

      Otel.Metrics.Meter.record(counter, 1, %{})
      _ = Otel.Metrics.MetricExporter.collect(config)

      Otel.Metrics.Meter.record(counter, 2, %{})
      [%{datapoints: [dp]}] = Otel.Metrics.MetricExporter.collect(config)
      assert hd(dp.exemplars).value == 2
    end

    test "config without :exemplars_tab — collect runs but datapoints carry no :exemplars",
         %{config: config} do
      counter = Otel.Metrics.Meter.create_counter("no_ex", [])
      Otel.Metrics.Meter.record(counter, 5, %{})

      [%{datapoints: [dp]}] =
        Otel.Metrics.MetricExporter.collect(Map.delete(config, :exemplars_tab))

      assert dp.value == 5
      refute Map.has_key?(dp, :exemplars)
    end
  end

  describe "force_flush/1" do
    setup do
      restart_sdk([])
      :ok
    end

    test "no instruments → :ok (no HTTP request sent)" do
      start_server_and_configure(200)

      assert :ok = Otel.Metrics.MetricExporter.force_flush()
      refute_receive :request_received, 200
    end

    test "recorded measurements → collect + HTTP POST" do
      start_server_and_configure(200)

      counter = Otel.Metrics.Meter.create_counter("flush_test", [])
      Otel.Metrics.Meter.record(counter, 7, %{})

      assert :ok = Otel.Metrics.MetricExporter.force_flush()
      assert_receive :request_received, 5_000
    end

    test "non-retryable 4xx is not retried (single POST)" do
      start_server_and_configure(400)

      counter = Otel.Metrics.Meter.create_counter("non_retryable", [])
      Otel.Metrics.Meter.record(counter, 1, %{})

      assert :ok = Otel.Metrics.MetricExporter.force_flush()
      assert_receive :request_received, 5_000
      refute_receive :request_received, 200
    end
  end

  # --- Test helpers ---

  defp override_filter(%Otel.Metrics.Instrument{config: config} = inst, filter) do
    %{inst | config: %{config | exemplar_filter: filter}}
  end

  defp start_server_and_configure(status_code) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    parent = self()
    pid = spawn_link(fn -> accept_loop(listen, status_code, parent) end)

    on_exit(fn ->
      Application.delete_env(:otel, :req_options)
      :gen_tcp.close(listen)
      ref = Process.monitor(pid)
      receive do: ({:DOWN, ^ref, _, _, _} -> :ok), after: (1_000 -> :ok)
    end)

    Application.put_env(:otel, :req_options, base_url: "http://localhost:#{port}")
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
