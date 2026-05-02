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
    test "30: root span is sampled (no parent)", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())

      Otel.Trace.with_span(
        tracer,
        "scenario-30-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

    test "31: child of sampled remote parent is sampled", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<span_id::64>> = :crypto.strong_rand_bytes(8)

      sampled_parent = %Otel.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        # 0x01 = sampled
        trace_flags: 1,
        is_remote: true
      }

      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), sampled_parent)

      Otel.Trace.with_span(
        ctx,
        tracer,
        "scenario-31-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end

    test "32: child of not-sampled remote parent is dropped", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.Tracer.BehaviourProvider.get_tracer(scope())
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<span_id::64>> = :crypto.strong_rand_bytes(8)

      not_sampled_parent = %Otel.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        # 0x00 = not sampled
        trace_flags: 0,
        is_remote: true
      }

      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), not_sampled_parent)

      Otel.Trace.with_span(
        ctx,
        tracer,
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
end
