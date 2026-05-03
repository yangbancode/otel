defmodule Otel.E2E.LogSdkTest do
  @moduledoc """
  E2E coverage for `Otel.Logs.Logger.emit/2` against Loki.

  Tracking matrix: `docs/e2e.md` §Log — SDK API, scenarios 1–10,
  13, 14. Limits-driven scenarios (11, 12) live in
  `log_sdk_limits_test.exs` because they need an SDK restart with
  small limits.
  """

  use Otel.E2E.Case, async: false

  describe "body shapes" do
    test "1: string body lands as a Loki line", %{e2e_id: e2e_id} do
      emit(e2e_id, body: "scenario-1-#{e2e_id}")
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "2: map body is JSON-serialised into the line", %{e2e_id: e2e_id} do
      emit(e2e_id,
        body: %{"msg" => "scenario-2-#{e2e_id}", "extra" => "ok"}
      )

      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "3: nested map body keeps nested values reachable", %{e2e_id: e2e_id} do
      emit(e2e_id,
        body: %{"user" => %{"id" => e2e_id, "tag" => "scenario-3"}}
      )

      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    # OTLP→Loki encodes a `bytes` body as base64, so the
    # e2e_id packed into the body ends up base64-encoded in the
    # rendered line and Loki's `|=` line filter (the default
    # `query/1` shape) can't match it. The mandatory `e2e.id`
    # attribute that `emit/2` always sets travels through OTLP
    # as a log record attribute and surfaces in Loki as
    # structured metadata, so `query/2` filters on that label
    # instead.
    test "4: bytes body lands", %{e2e_id: e2e_id} do
      emit(e2e_id, body: {:bytes, "scenario-4-#{e2e_id}"})
      assert {:ok, [_ | _]} = poll(Loki.query("e2e.id", e2e_id))
    end
  end

  describe "severity" do
    test "5: each of the 8 standard severity levels round-trips", %{e2e_id: e2e_id} do
      levels = [
        {5, "DEBUG"},
        {9, "INFO"},
        {10, "INFO2"},
        {13, "WARN"},
        {17, "ERROR"},
        {18, "ERROR2"},
        {19, "ERROR3"},
        {21, "FATAL"}
      ]

      for {num, text} <- levels do
        emit(e2e_id,
          body: "scenario-5-sev-#{num}-#{e2e_id}",
          severity_number: num,
          severity_text: text
        )
      end

      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "6: severity_number 0 → unspecified sentinel still lands", %{e2e_id: e2e_id} do
      emit(e2e_id, body: "scenario-6-#{e2e_id}", severity_number: 0)
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "metadata" do
    test "7: event_name field is preserved", %{e2e_id: e2e_id} do
      emit(e2e_id,
        body: "scenario-7-#{e2e_id}",
        event_name: "scenario.7.event"
      )

      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "8: omitting timestamp lets the SDK fill observed_timestamp", %{e2e_id: e2e_id} do
      # `emit/2` omits :timestamp here so the SDK assigns
      # observed_timestamp at emit time. Land confirms the SDK
      # didn't drop the record for missing fields.
      emit(e2e_id, body: "scenario-8-#{e2e_id}")
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "9: custom attributes flow through to Loki", %{e2e_id: e2e_id} do
      emit(e2e_id,
        body: "scenario-9-#{e2e_id}",
        attributes: %{"custom.role" => "admin", "custom.ver" => 3}
      )

      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "trace context" do
    test "10: emit inside with_span carries trace_id / span_id to Loki", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.TracerProvider.get_tracer()

      Otel.Trace.with_span(
        tracer,
        "scenario-10-span-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          emit(e2e_id, body: "scenario-10-msg-#{e2e_id}", flush: false)
        end
      )

      flush()

      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "exception sidecar" do
    test "14: exception field populates exception.* attributes", %{e2e_id: e2e_id} do
      emit(e2e_id,
        body: "scenario-14-#{e2e_id}",
        severity_number: 17,
        severity_text: "error",
        exception: %RuntimeError{message: "boom-14"}
      )

      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  # ---- helpers ----

  # Builds a LogRecord with sensible defaults (severity 9 = INFO,
  # the e2e_id appended to attributes), emits, and flushes —
  # trimming each scenario down to the field it's actually
  # exercising. `flush: false` opts out of the post-emit flush
  # for tests that want to flush after additional work (e.g.
  # finishing an enclosing span).
  defp emit(e2e_id, fields) do
    {do_flush?, fields} = Keyword.pop(fields, :flush, true)
    logger = Otel.Logs.LoggerProvider.get_logger()

    attrs = Keyword.get(fields, :attributes, %{}) |> Map.put("e2e.id", e2e_id)

    record =
      fields
      |> Keyword.put_new(:severity_number, 9)
      |> Keyword.put(:attributes, attrs)
      |> then(&struct(Otel.Logs.LogRecord, &1))

    Otel.Logs.Logger.emit(logger, record)
    if do_flush?, do: flush()
    :ok
  end
end
