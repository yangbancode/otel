defmodule Otel.E2E.ConcurrencyTest do
  @moduledoc """
  E2E coverage for the SDK under concurrent / high-volume
  load. The single-process happy-path scenarios in the
  per-signal modules cover *what* is exported; this module
  covers *how* the SDK behaves when many emitters or many
  records flow through at once.

  Tracking matrix: `docs/e2e.md` §Concurrency, scenarios 1-4.
  """

  use Otel.E2E.Case, async: false

  describe "fan-out" do
    test "1: 50 concurrent tasks each emit one span — all land", %{e2e_id: e2e_id} do
      names = for i <- 1..50, do: "scenario-conc-1-#{e2e_id}-#{i}"

      names
      |> Task.async_stream(
        fn name ->
          Otel.Trace.with_span(
            name,
            [attributes: %{"e2e.id" => e2e_id}],
            fn _ -> :ok end
          )
        end,
        max_concurrency: 50,
        ordered: false
      )
      |> Stream.run()

      flush()

      # 50 root spans → 50 separate traces; pass an explicit
      # `:limit` past Tempo's default page size.
      observed =
        e2e_id
        |> trace_spans(limit: 60)
        |> Enum.map(& &1["name"])
        |> MapSet.new()

      assert MapSet.equal?(observed, MapSet.new(names))
    end

    test "2: 1000 child spans under one parent land within force_flush",
         %{e2e_id: e2e_id} do
      parent_name = "parent-conc-2-#{e2e_id}"

      # Single parent so all 1001 spans share a trace_id —
      # avoids fanning Tempo's tag-based search across 1000
      # root traces (which would then need pagination beyond
      # the default page size). The interesting signal is the
      # BatchProcessor's behaviour under sustained burst, not
      # Tempo's search throughput.
      Otel.Trace.with_span(
        parent_name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          for i <- 1..1000 do
            Otel.Trace.with_span(
              "child-conc-2-#{e2e_id}-#{i}",
              [attributes: %{"e2e.id" => e2e_id}],
              fn _ -> :ok end
            )
          end
        end
      )

      flush()

      spans = trace_spans(e2e_id)
      children = Enum.filter(spans, &String.starts_with?(&1["name"], "child-conc-2-"))
      assert length(children) == 1000
    end
  end

  describe "multi-signal" do
    test "3: trace + log + metric emitted concurrently — each backend receives",
         %{e2e_id: e2e_id} do
      logger = Otel.Logs.LoggerProvider.get_logger()
      meter = Otel.Metrics.MeterProvider.get_meter()
      counter = Otel.Metrics.Meter.create_counter(meter, "e2e_scenario_conc_3_#{e2e_id}")

      [
        Task.async(fn ->
          Otel.Trace.with_span(
            "scenario-conc-3-#{e2e_id}",
            [attributes: %{"e2e.id" => e2e_id}],
            fn _ -> :ok end
          )
        end),
        Task.async(fn ->
          Otel.Logs.Logger.emit(logger, %Otel.Logs.LogRecord{
            severity_number: 9,
            body: "scenario-conc-3-#{e2e_id}",
            attributes: %{"e2e.id" => e2e_id}
          })
        end),
        Task.async(fn ->
          Otel.Metrics.Counter.add(counter, 1, %{"e2e.id" => e2e_id})
        end)
      ]
      |> Task.await_many()

      flush()

      assert [_ | _] = trace_spans(e2e_id)
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))

      assert {:ok, [_ | _]} =
               poll(Mimir.query(e2e_id, "e2e_scenario_conc_3_#{e2e_id}_total"))
    end
  end

  describe "context propagation" do
    test "4: parent span context flows into Task.async_stream children",
         %{e2e_id: e2e_id} do
      parent_name = "parent-conc-4-#{e2e_id}"

      Otel.Trace.with_span(
        parent_name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          parent_ctx = Otel.Ctx.current()

          1..10
          |> Task.async_stream(
            fn i ->
              # Children run in fresh processes; explicitly
              # attach the captured parent context so the SDK
              # links the child span to the parent.
              Otel.Ctx.attach(parent_ctx)

              Otel.Trace.with_span(
                "child-conc-4-#{e2e_id}-#{i}",
                [attributes: %{"e2e.id" => e2e_id}],
                fn _ -> :ok end
              )
            end,
            max_concurrency: 10,
            ordered: false
          )
          |> Stream.run()
        end
      )

      flush()

      spans = trace_spans(e2e_id)
      parent = Enum.find(spans, &(&1["name"] == parent_name))
      children = Enum.filter(spans, &String.starts_with?(&1["name"], "child-conc-4-"))

      assert parent
      assert length(children) == 10

      for child <- children do
        assert child["parentSpanId"] == parent["spanId"],
               "child #{child["name"]} should link to parent #{parent_name}"

        assert child["traceId"] == parent["traceId"]
      end
    end
  end

  # ---- helpers ----

  @spec trace_spans(e2e_id :: String.t(), opts :: keyword()) :: [map()]
  defp trace_spans(e2e_id, opts \\ []) do
    {:ok, traces} = poll(Tempo.search(e2e_id, opts))

    Enum.flat_map(traces, fn %{"traceID" => trace_id} ->
      {:ok, body} = HTTP.get(Tempo.get_trace(trace_id))
      {:ok, %{"batches" => batches}} = Jason.decode(body)

      Enum.flat_map(batches, fn b ->
        Enum.flat_map(b["scopeSpans"] || [], &(&1["spans"] || []))
      end)
    end)
  end
end
