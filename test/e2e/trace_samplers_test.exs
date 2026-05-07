defmodule Otel.E2E.TraceSamplersTest do
  @moduledoc """
  E2E coverage for `Otel.Trace.Sampler` (hardcoded
  `parentbased_always_on`) against Tempo.

  The SDK ships only one sampler — there is no per-test
  sampler reconfiguration. The three observable behaviours
  are: root → sampled, sampled remote parent → child sampled,
  not-sampled remote parent → child dropped.

  Tracking matrix: `docs/e2e.md` §Trace, scenarios 30-32.
  """

  use Otel.E2E.Case, async: false

  describe "parentbased_always_on (hardcoded)" do
    test "30: root span is sampled (no parent) and has blank parentSpanId",
         %{e2e_id: e2e_id} do
      name = "scenario-30-#{e2e_id}"

      Otel.Trace.with_span(
        name,
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      assert span["name"] == name
      # Root span has no parent — confirms sampler took the root
      # branch (record_and_sample) rather than the child branch.
      assert blank_parent?(span)
    end

    test "31: child of sampled remote parent inherits trace_id + parentSpanId",
         %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<span_id::64>> = :crypto.strong_rand_bytes(8)

      sampled_parent =
        Otel.Trace.SpanContext.new(%{
          trace_id: trace_id,
          span_id: span_id,
          # 0x01 = sampled
          trace_flags: 1,
          is_remote: true
        })

      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), sampled_parent)

      Otel.Trace.with_span(
        ctx,
        "scenario-31-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()

      assert [span] = trace_spans(e2e_id)
      # Child's traceId matches the remote parent's trace_id and
      # parentSpanId matches the remote parent's span_id —
      # confirms the sampler took the parent-sampled branch and
      # the SDK correctly threaded the parent's identity.
      assert span["traceId"] == otlp_id(trace_id, 128)
      assert span["parentSpanId"] == otlp_id(span_id, 64)
    end

    test "32: child of not-sampled remote parent is dropped", %{e2e_id: e2e_id} do
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<span_id::64>> = :crypto.strong_rand_bytes(8)

      not_sampled_parent =
        Otel.Trace.SpanContext.new(%{
          trace_id: trace_id,
          span_id: span_id,
          # 0x00 = not sampled
          trace_flags: 0,
          is_remote: true
        })

      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), not_sampled_parent)

      Otel.Trace.with_span(
        ctx,
        "scenario-32-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      # Drop happens at sampling time — no traffic ever reaches the
      # exporter; `fetch/1` is the right shape, not `poll/1`.
      assert {:ok, []} = fetch(Tempo.search(e2e_id))
    end
  end

  # ---- helpers (mirror those in trace_test.exs) ----

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

  @spec blank_parent?(span :: map()) :: boolean()
  defp blank_parent?(span) do
    case span["parentSpanId"] do
      nil -> true
      "" -> true
      str -> str =~ ~r/^A+={0,2}$/
    end
  end
end
