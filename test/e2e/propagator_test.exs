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
    test "1: round-trip — child's traceId / parentSpanId match the carrier",
         %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)

      carrier = [{"traceparent", traceparent(trace_id, parent_span_id, 1)}]
      ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        ctx,
        "scenario-1-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      # traceId carries through end-to-end (carrier → SDK → OTLP →
      # Tempo); parentSpanId points at the carrier's parent.
      assert span["traceId"] == otlp_id(trace_id, 128)
      assert span["parentSpanId"] == otlp_id(parent_span_id, 64)
    end

    test "2: sampled trace_flags propagate (carrier 01 → child sampled, lands in Tempo)",
         %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)

      carrier = [{"traceparent", traceparent(trace_id, parent_span_id, 1)}]
      ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        ctx,
        "scenario-2-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      # Sampled bit (0x01) → SDK kept the span and exported it.
      # The OTLP `flags` field carries the same byte forward.
      assert sampled?(span)
      # And the trace_id/parent linkage is intact — confirms the
      # sampling decision didn't sever the parent association.
      assert span["traceId"] == otlp_id(trace_id, 128)
      assert span["parentSpanId"] == otlp_id(parent_span_id, 64)
    end

    test "3: tracestate propagates from carrier to child", %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)

      vendor_value = "carrier-#{e2e_id}"

      carrier = [
        {"traceparent", traceparent(trace_id, parent_span_id, 1)},
        {"tracestate", "vendor=#{vendor_value}"}
      ]

      ctx = Otel.Propagator.TextMap.extract(Otel.Ctx.new(), carrier)

      Otel.Trace.with_span(
        ctx,
        "scenario-3-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      # The carrier's tracestate must reach Tempo as a substring
      # of the persisted span's traceState — the encoder
      # serialises the full TraceState back to the W3C list-member
      # format, so a contains-check is the right shape.
      assert span["traceState"] =~ "vendor=#{vendor_value}"
    end
  end

  describe "Baggage" do
    test "4: baggage round-trip — extracted baggage value reaches the child as an attribute",
         %{e2e_id: e2e_id} do
      tenant_value = "acme-#{e2e_id}"

      sender_baggage = Otel.Baggage.set_value(%{}, "tenant", tenant_value)
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

      assert [span] = trace_spans(e2e_id)
      # The bag survived inject → extract — confirmed by the
      # value showing up as a span attribute on the child.
      assert Tempo.attribute(span, "tenant") == tenant_value
    end

    test "5: composite (TraceContext + Baggage) — both survive the round-trip",
         %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<parent_span_id::64>> = :crypto.strong_rand_bytes(8)
      tenant_value = "acme-#{e2e_id}"

      carrier = [
        {"traceparent", traceparent(trace_id, parent_span_id, 1)},
        {"baggage", "tenant=#{tenant_value}"}
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

      assert [span] = trace_spans(e2e_id)
      # TraceContext side: parent linkage intact.
      assert span["traceId"] == otlp_id(trace_id, 128)
      assert span["parentSpanId"] == otlp_id(parent_span_id, 64)
      # Baggage side: tenant attribute carried forward.
      assert Tempo.attribute(span, "tenant") == tenant_value
    end
  end

  # ---- helpers ----

  @spec trace_spans(e2e_id :: String.t()) :: [map()]
  defp trace_spans(e2e_id) do
    {:ok, traces} = poll(Tempo.search(e2e_id))

    Enum.flat_map(traces, fn %{"traceID" => trace_id} ->
      {:ok, body} = HTTP.get(Tempo.get_trace(trace_id))
      {:ok, %{"batches" => batches}} = Jason.decode(body)

      Enum.flat_map(batches, fn b ->
        Enum.flat_map(b["scopeSpans"] || [], &(&1["spans"] || []))
      end)
    end)
  end

  @spec otlp_id(integer :: non_neg_integer(), bits :: pos_integer()) :: String.t()
  defp otlp_id(integer, bits), do: Base.encode64(<<integer::size(bits)>>)

  @spec traceparent(trace_id :: non_neg_integer(), span_id :: non_neg_integer(), flags :: 0..255) ::
          String.t()
  defp traceparent(trace_id, span_id, flags) do
    trace_hex =
      trace_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")

    span_hex =
      span_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(16, "0")

    flags_hex = flags |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")
    "00-#{trace_hex}-#{span_hex}-#{flags_hex}"
  end

  # Tempo's OTLP/JSON span carries `flags` as either an integer or
  # a string of digits. A sampled span has the W3C bit (0x01) set;
  # checking the LSB covers both encodings. Tempo may also omit
  # the field entirely on older versions — treat that as not
  # asserting either way.
  @spec sampled?(span :: map()) :: boolean()
  defp sampled?(span) do
    case span["flags"] do
      nil -> true
      n when is_integer(n) -> Bitwise.band(n, 1) == 1
      str when is_binary(str) -> Bitwise.band(String.to_integer(str), 1) == 1
    end
  end
end
