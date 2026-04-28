defmodule Otel.E2E.TraceSamplersTest do
  @moduledoc """
  E2E coverage for `Otel.SDK.Trace.Sampler` against Tempo.

  Each describe block restarts the SDK with a different sampler
  config so the sampling decision is observable end-to-end via
  span presence (or absence) in Tempo.

  Tracking matrix: `docs/e2e.md` §Trace, scenarios 30–33.
  """

  use Otel.E2E.Case, async: false

  describe "always_on" do
    setup do
      restart_sdk_with(sampler: :always_on)
    end

    test "30: always_on emits the span", %{e2e_id: e2e_id} do
      emit("scenario-30-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  describe "always_off" do
    setup do
      restart_sdk_with(sampler: :always_off)
    end

    test "31: always_off drops the span", %{e2e_id: e2e_id} do
      emit("scenario-31-#{e2e_id}", e2e_id)
      # `:always_off` drops the span at sampling time, so no
      # traffic ever reaches the exporter — `fetch/1` is the
      # right shape, not `poll/1`.
      assert {:ok, []} = fetch(Tempo.search(e2e_id))
    end
  end

  describe "parentbased_always_on" do
    setup do
      restart_sdk_with(sampler: :parentbased_always_on)
    end

    test "32: parentbased_always_on inherits a sampled remote parent", %{e2e_id: e2e_id} do
      tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())
      <<trace_id::128>> = :crypto.strong_rand_bytes(16)
      <<span_id::64>> = :crypto.strong_rand_bytes(8)

      sampled_parent = %Otel.API.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        # 0x01 = sampled
        trace_flags: 1,
        is_remote: true
      }

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), sampled_parent)

      Otel.API.Trace.with_span(
        ctx,
        tracer,
        "scenario-32-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ -> :ok end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  describe "traceidratio 1.0" do
    setup do
      restart_sdk_with(sampler: {:traceidratio, 1.0})
    end

    test "33: traceidratio 1.0 emits the span", %{e2e_id: e2e_id} do
      emit("scenario-33-#{e2e_id}", e2e_id)
      assert {:ok, [_ | _]} = poll(Tempo.search(e2e_id))
    end
  end

  # ---- helpers ----

  defp restart_sdk_with(opts) do
    prev = Application.get_env(:otel, :trace, [])
    Application.stop(:otel)
    Application.put_env(:otel, :trace, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.put_env(:otel, :trace, prev)
      Application.ensure_all_started(:otel)
    end)

    :ok
  end

  defp emit(name, e2e_id) do
    tracer = Otel.API.Trace.TracerProvider.get_tracer(scope())

    Otel.API.Trace.with_span(
      tracer,
      name,
      [attributes: %{"e2e.id" => e2e_id}],
      fn _ -> :ok end
    )

    flush()
  end
end
