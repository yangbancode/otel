defmodule Otel.TelemetryReporterTest do
  # async: false — shares the global Otel.Metrics ETS tables.
  use ExUnit.Case, async: false

  import Telemetry.Metrics

  defp restart_sdk(env), do: Otel.TestSupport.restart_with(env)
  defp datapoints(name), do: collect_datapoints(name)

  setup do
    restart_sdk(metrics: [readers: []])
    :ok
  end

  defp collect_datapoints(name) do
    [metric] =
      Otel.Metrics.MetricExporter.collect()
      |> Enum.filter(&(&1.name == name))

    metric.datapoints
  end

  defp start_reporter!(metrics) do
    pid = start_supervised!({Otel.TelemetryReporter, metrics: metrics})
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :shutdown) end)
    pid
  end

  describe "Counter" do
    test "counts events regardless of measurement value" do
      start_reporter!([counter("http.req.stop.duration", tags: [:method])])

      :telemetry.execute([:http, :req, :stop], %{duration: 12}, %{method: "GET"})
      :telemetry.execute([:http, :req, :stop], %{duration: 99}, %{method: "GET"})
      :telemetry.execute([:http, :req, :stop], %{duration: 5}, %{method: "POST"})

      [dp_get] =
        Enum.filter(datapoints("http.req.stop.duration"), &(&1.attributes["method"] == "GET"))

      [dp_post] =
        Enum.filter(datapoints("http.req.stop.duration"), &(&1.attributes["method"] == "POST"))

      assert dp_get.value == 2
      assert dp_post.value == 1
    end
  end

  describe "Sum" do
    test "non-monotonic by default → UpDownCounter (accepts negatives)" do
      start_reporter!([sum("inventory.delta", measurement: :delta)])

      :telemetry.execute([:inventory], %{delta: 5}, %{})
      :telemetry.execute([:inventory], %{delta: -2}, %{})

      [dp] = datapoints("inventory.delta")
      assert dp.value == 3
    end

    test "reporter_options[:monotonic]: true → Counter (rejects negatives at SDK level)" do
      start_reporter!([
        sum("bytes.sent", measurement: :bytes, reporter_options: [monotonic: true])
      ])

      :telemetry.execute([:bytes], %{bytes: 100}, %{})
      :telemetry.execute([:bytes], %{bytes: 250}, %{})

      [dp] = datapoints("bytes.sent")
      assert dp.value == 350
    end
  end

  describe "LastValue" do
    test "keeps the most recent measurement" do
      start_reporter!([last_value("vm.memory.total", measurement: :total)])

      :telemetry.execute([:vm, :memory], %{total: 1000}, %{})
      :telemetry.execute([:vm, :memory], %{total: 2500}, %{})

      [dp] = datapoints("vm.memory.total")
      assert dp.value == 2500
    end
  end

  describe "Summary / Distribution" do
    test "summary → Histogram with default boundaries" do
      start_reporter!([summary("rpc.duration", measurement: :duration)])

      for v <- [10, 50, 200], do: :telemetry.execute([:rpc], %{duration: v}, %{})

      [dp] = datapoints("rpc.duration")
      assert dp.value.count == 3
      assert dp.value.sum == 260
    end

    test "distribution with custom buckets via reporter_options" do
      start_reporter!([
        distribution("query.duration",
          measurement: :duration,
          reporter_options: [buckets: [10, 100, 1000]]
        )
      ])

      :telemetry.execute([:query], %{duration: 5}, %{})
      :telemetry.execute([:query], %{duration: 50}, %{})
      :telemetry.execute([:query], %{duration: 500}, %{})
      :telemetry.execute([:query], %{duration: 5000}, %{})

      [dp] = datapoints("query.duration")
      assert dp.value.boundaries == [10, 100, 1000]
      assert dp.value.count == 4
    end
  end

  describe "tags / tag_values" do
    test "tags keys flow to OTel attributes (atom → string)" do
      start_reporter!([counter("evt.tag.count", tags: [:role, :region])])

      :telemetry.execute([:evt, :tag], %{count: 1}, %{
        role: :admin,
        region: "us-east",
        ignored: "xxx"
      })

      [dp] = datapoints("evt.tag.count")
      assert dp.attributes == %{"role" => "admin", "region" => "us-east"}
    end

    test "tag_values transforms metadata before tagging" do
      tag_fn = fn meta -> %{user_id: meta.user.id} end

      start_reporter!([
        counter("login.event.count", tags: [:user_id], tag_values: tag_fn)
      ])

      :telemetry.execute([:login, :event], %{count: 1}, %{user: %{id: 42, name: "alice"}})

      [dp] = datapoints("login.event.count")
      assert dp.attributes == %{"user_id" => 42}
    end
  end

  describe "unit conversion" do
    test "{:native, :millisecond} converts measurement before record" do
      start_reporter!([
        last_value("delay.observed.ms",
          event_name: [:delay, :observed],
          measurement: :ms_native,
          unit: {:native, :millisecond}
        )
      ])

      ms_native = System.convert_time_unit(750, :millisecond, :native)
      :telemetry.execute([:delay, :observed], %{ms_native: ms_native}, %{})

      [dp] = datapoints("delay.observed.ms")
      assert dp.value == 750
    end

    test "{:byte, :kilobyte} converts decimally (1 kB = 1000 B)" do
      start_reporter!([
        last_value("vm.heap.kb",
          event_name: [:vm, :heap],
          measurement: :bytes,
          unit: {:byte, :kilobyte}
        )
      ])

      :telemetry.execute([:vm, :heap], %{bytes: 4096}, %{})

      [dp] = datapoints("vm.heap.kb")
      assert dp.value == 4.096
    end
  end

  describe ":keep / :drop predicates" do
    test ":keep returning false skips the event" do
      start_reporter!([
        counter("env.filter.count", keep: fn meta -> meta[:env] == :prod end)
      ])

      :telemetry.execute([:env, :filter], %{count: 1}, %{env: :test})
      :telemetry.execute([:env, :filter], %{count: 1}, %{env: :prod})

      [dp] = datapoints("env.filter.count")
      assert dp.value == 1
    end
  end

  describe "missing measurement" do
    test "skipped silently when measurement key is absent" do
      start_reporter!([sum("rare.miss.value", measurement: :missing_key)])

      # No raise expected.
      :telemetry.execute([:rare, :miss], %{other: 1}, %{})

      assert [] = datapoints_or_empty("rare.miss.value")
    end
  end

  describe "lifecycle" do
    test "terminate detaches handlers; later events do nothing" do
      pid = start_reporter!([counter("ev.stop.count")])

      :telemetry.execute([:ev, :stop], %{count: 1}, %{})
      [dp_pre] = datapoints("ev.stop.count")
      assert dp_pre.value == 1

      GenServer.stop(pid)
      # Reporter detaches synchronously inside terminate/2.

      :telemetry.execute([:ev, :stop], %{count: 1}, %{})
      [dp] = datapoints("ev.stop.count")
      assert dp.value == 1
    end
  end

  defp datapoints_or_empty(name) do
    Otel.Metrics.MetricExporter.collect()
    |> Enum.find(&(&1.name == name))
    |> case do
      nil -> []
      metric -> metric.datapoints
    end
  end
end
