defmodule Otel.E2E.LogSdkTest do
  @moduledoc """
  E2E coverage for `Otel.Logs.Logger.emit/2` against Loki.

  Each scenario emits a LogRecord (or several) carrying a
  per-test unique substring (`"scenario-N-{e2e_id}"`),
  force-flushes, then asserts on the rendered Loki line **and**
  the stream attributes attached to the matching entry —
  severity, custom attributes, trace context, etc.

  ## Loki indexing notes

  This otel-lgtm bundle indexes only `service_name` and
  `deployment_environment` as Loki stream labels (verified via
  `/api/v1/labels`). Custom OTel attributes / `severity_*` /
  `trace_id` / `span_id` show up in the response's `stream`
  object but are *categorized* labels, not stream-selector
  indexes — `{e2e_id="X"}` returns nothing even when the data
  is present. We therefore filter on a unique line substring
  via `|=` and read the categorized labels off the matched
  entry's `stream` map (via `Loki.labels/1` / `Loki.attribute/2`).

  Tracking matrix: `docs/e2e.md` §Log — SDK API, scenarios 1–10,
  13, 14. Limits-driven scenarios (11, 12) live in
  `log_sdk_limits_test.exs` because they need an SDK restart with
  small limits.

  Scenario 7 (`event_name` field) is omitted: this otel-lgtm
  bundle's Loki exporter does not promote LogRecord
  `event_name` to a stream label or any other queryable
  position. The wire-format propagation is verified at the
  encoder unit-test level (`encoder_test.exs`).
  """

  use Otel.E2E.Case, async: false

  describe "body shapes" do
    test "1: string body lands as a Loki line", %{e2e_id: e2e_id} do
      body = "scenario-1-#{e2e_id}"
      emit(e2e_id, body: body)

      assert {:ok, results} = poll(Loki.query(body))
      assert body in Loki.lines(results)
    end

    test "2: map body is JSON-serialised into the line", %{e2e_id: e2e_id} do
      token = "scenario-2-#{e2e_id}"
      emit(e2e_id, body: %{"msg" => token, "extra" => "ok"})

      assert {:ok, results} = poll(Loki.query(token))
      [line] = Loki.lines(results)
      # The map body lands as JSON — both keys and values
      # round-trip through OTLP→Loki.
      assert line =~ token
      assert line =~ ~s("extra")
      assert line =~ ~s("ok")
    end

    test "3: nested map body keeps nested values reachable", %{e2e_id: e2e_id} do
      token = "scenario-3-#{e2e_id}"
      emit(e2e_id, body: %{"user" => %{"id" => e2e_id, "tag" => token}})

      assert {:ok, results} = poll(Loki.query(token))
      [line] = Loki.lines(results)
      assert line =~ ~s("user")
      assert line =~ token
      assert line =~ e2e_id
    end

    test "4: bytes body lands; base64-encoded payload decodes back to the raw bytes",
         %{e2e_id: e2e_id} do
      raw = "scenario-4-#{e2e_id}"
      expected_b64 = Base.encode64(raw)
      emit(e2e_id, body: {:bytes, raw})

      assert {:ok, results} = poll(Loki.query(expected_b64))
      [line] = Loki.lines(results)
      # Bytes body is base64-encoded on the wire; decode confirms
      # the raw payload survived round-trip.
      assert {:ok, ^raw} = Base.decode64(line)
    end
  end

  describe "severity" do
    test "5: each of the 8 standard severity levels lands with its number+text label",
         %{e2e_id: e2e_id} do
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

      # Each level emits a distinct line — query each one
      # separately to retrieve its `severity_*` labels.
      for {num, text} <- levels do
        body = "scenario-5-sev-#{num}-#{e2e_id}"
        assert {:ok, results} = poll(Loki.query(body))
        labels = Loki.labels(results)

        assert labels["severity_text"] == text,
               "level #{num}: expected text=#{text}, got #{inspect(labels["severity_text"])}"

        assert labels["severity_number"] == Integer.to_string(num),
               "level #{num}: expected number=#{num}, got #{inspect(labels["severity_number"])}"
      end
    end

    test "6: severity_number 0 → unspecified sentinel still lands", %{e2e_id: e2e_id} do
      body = "scenario-6-#{e2e_id}"
      emit(e2e_id, body: body, severity_number: 0)

      assert {:ok, results} = poll(Loki.query(body))
      [line] = Loki.lines(results)
      assert line == body
      # severity_number=0 is the proto3 default → label may be
      # "0" or absent; assert it didn't get coerced to something
      # weird like "9" (the test's default INFO).
      labels = Loki.labels(results)
      assert labels["severity_number"] in [nil, "0", ""]
    end
  end

  describe "metadata" do
    test "8: omitting timestamp lets the SDK fill observed_timestamp", %{e2e_id: e2e_id} do
      now_ns = System.system_time(:nanosecond)
      body = "scenario-8-#{e2e_id}"
      emit(e2e_id, body: body)

      assert {:ok, results} = poll(Loki.query(body))
      [%{"values" => [[ts_str, _line] | _]} | _] = results
      ts_ns = String.to_integer(ts_str)
      delta_ms = abs(ts_ns - now_ns) |> div(1_000_000)
      # Loki indexes the observed_timestamp the SDK assigned at
      # emit time; it should be within a generous 30 s window of
      # the test's start (covers SDK + flush + Loki ingest lag).
      assert delta_ms < 30_000, "observed_timestamp drift #{delta_ms} ms > 30 s"
    end

    test "9: custom attributes flow through to Loki as categorized labels",
         %{e2e_id: e2e_id} do
      body = "scenario-9-#{e2e_id}"
      emit(e2e_id, body: body, attributes: %{"custom.role" => "admin", "custom.ver" => 3})

      assert {:ok, results} = poll(Loki.query(body))
      labels = Loki.labels(results)
      # `.` → `_` sanitisation when promoted to labels.
      assert labels["custom_role"] == "admin"
      assert labels["custom_ver"] == "3"
    end
  end

  describe "trace context" do
    test "10: emit inside with_span carries trace_id / span_id labels to Loki",
         %{e2e_id: e2e_id} do
      body = "scenario-10-msg-#{e2e_id}"
      span_ctx_ref = make_ref()

      Otel.Trace.with_span(
        "scenario-10-span-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Process.put(span_ctx_ref, span_ctx)
          emit(e2e_id, body: body, flush: false)
        end
      )

      flush()

      span_ctx = Process.get(span_ctx_ref)

      expected_trace_id_hex =
        span_ctx.trace_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(32, "0")

      expected_span_id_hex =
        span_ctx.span_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(16, "0")

      assert {:ok, results} = poll(Loki.query(body))
      labels = Loki.labels(results)
      # SDK threaded the active SpanContext into the LogRecord at
      # emit time — both ids surface as labels in hex form.
      assert labels["trace_id"] == expected_trace_id_hex
      assert labels["span_id"] == expected_span_id_hex
    end
  end

  describe "exception sidecar" do
    test "14: exception field populates exception.* labels", %{e2e_id: e2e_id} do
      body = "scenario-14-#{e2e_id}"

      emit(e2e_id,
        body: body,
        severity_number: 17,
        severity_text: "error",
        exception: %RuntimeError{message: "boom-14"}
      )

      assert {:ok, results} = poll(Loki.query(body))
      labels = Loki.labels(results)
      # `exception.type` and `exception.message` populated by the
      # SDK from the Exception struct end up as categorized labels
      # via the same `.` → `_` sanitisation.
      assert labels["exception_type"] =~ "RuntimeError"
      assert labels["exception_message"] == "boom-14"
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

    attrs = Keyword.get(fields, :attributes, %{}) |> Map.put("e2e.id", e2e_id)

    record =
      fields
      |> Keyword.put_new(:severity_number, 9)
      |> Keyword.put(:attributes, attrs)
      |> Map.new()
      |> Otel.Logs.LogRecord.new()

    Otel.Logs.emit(record)
    if do_flush?, do: flush()
    :ok
  end
end
