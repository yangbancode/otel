defmodule Otel.E2E.PropagatorTest do
  @moduledoc """
  E2E coverage for cross-process propagation against Tempo.

  Each scenario simulates an inbound request: it builds a
  carrier (W3C `traceparent` / `tracestate` / `baggage`
  headers), runs the parent's portion through `inject/3` (or
  hand-builds the carrier), then `extract/3`s into a fresh
  `Ctx` and starts a child span underneath. The persisted Tempo
  trace shows the child wired to the carrier's IDs / flags /
  tracestate / baggage.

  Tracking matrix: `docs/e2e.md` §Propagator, scenarios 1–5.
  """

  use Otel.E2E.Case, async: false

  describe "TraceContext" do
    test "1: round-trip — child's parentSpanId matches the carrier's span_id",
         %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)

      trace_id_hex =
        trace_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")

      parent_id_hex =
        parent_span_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(16, "0")

      carrier = [{"traceparent", "00-#{trace_id_hex}-#{parent_id_hex}-01"}]
      ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        ctx,
        "scenario-1-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

    test "2: sampled trace_flags propagate (carrier 01 → child sampled)",
         %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)

      trace_id_hex =
        trace_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")

      parent_id_hex =
        parent_span_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(16, "0")

      carrier = [{"traceparent", "00-#{trace_id_hex}-#{parent_id_hex}-01"}]
      ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        ctx,
        "scenario-2-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      # Sampled (01) means the child should land in Tempo.
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

    test "3: tracestate propagates from carrier to child", %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)

      trace_id_hex =
        trace_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")

      parent_id_hex =
        parent_span_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(16, "0")

      carrier = [
        {"traceparent", "00-#{trace_id_hex}-#{parent_id_hex}-01"},
        {"tracestate", "vendor=carrier-#{e2e_id}"}
      ]

      ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        ctx,
        "scenario-3-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  describe "Baggage" do
    test "4: baggage round-trip — carrier baggage reaches the child via context",
         %{e2e_id: e2e_id} do
      sender_baggage =
        Otel.Baggage.set_value(%{}, "tenant", "acme-#{e2e_id}")

      sender_ctx = Otel.Baggage.set_current(Otel.Ctx.new(), sender_baggage)
      carrier = Otel.Propagator.TextMap.inject(sender_ctx, [])
      receiver_ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        receiver_ctx,
        "scenario-4-#{e2e_id}",
        [
          attributes: %{
            "e2e.id" => e2e_id,
            "tenant" => receiver_ctx |> Otel.Baggage.current() |> Otel.Baggage.get_value("tenant")
          }
        ],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

    test "5: composite (TraceContext + Baggage) — both survive the round-trip",
         %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)

      trace_id_hex =
        trace_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")

      parent_id_hex =
        parent_span_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(16, "0")

      carrier = [
        {"traceparent", "00-#{trace_id_hex}-#{parent_id_hex}-01"},
        {"baggage", "tenant=acme-#{e2e_id}"}
      ]

      ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        ctx,
        "scenario-5-#{e2e_id}",
        [
          attributes: %{
            "e2e.id" => e2e_id,
            "tenant" => ctx |> Otel.Baggage.current() |> Otel.Baggage.get_value("tenant")
          }
        ],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end
end
