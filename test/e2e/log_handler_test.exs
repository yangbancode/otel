defmodule Otel.E2E.LogHandlerTest do
  @moduledoc """
  E2E coverage for the `:logger` → OTel bridge
  (`Otel.LoggerHandler`) against Loki.

  `setup_all` registers `:otel_e2e` as a `:logger` handler so
  `:logger.log/3` calls flow through `Otel.LoggerHandler` →
  `Otel.Logs.Logger.emit/2` → the SDK pipeline → Loki. The
  handler is removed in `on_exit` so subsequent e2e modules
  don't see duplicated emits.

  Scenarios call `:logger.log/3` directly rather than the Elixir
  `Logger.*` macros so the test file doesn't have to register
  every transient metadata key in the application's `:logger`
  config — the handler bridge is the same on both surfaces.

  ## Loki indexing notes

  The otel-lgtm collector promotes most OTel attributes to
  *categorized* Loki labels (`stream` field on each query
  result), with the standard `.` → `_` sanitisation.
  `severity_text` arrives lowercase via the handler bridge
  (`info` / `error` / etc.) — distinct from the SDK API path
  which preserves the caller-supplied case. Every assertion in
  this file filters on a unique line substring (line filter
  `|=`), reads `stream` labels via `Loki.labels/1`, and asserts
  on the specific keys + values the scenario exercises.

  Tracking matrix: `docs/e2e.md` §Log — `:logger` Handler bridge,
  scenarios 1–20.
  """

  use Otel.E2E.Case, async: false

  @handler_id :otel_e2e

  setup_all do
    :logger.add_handler(@handler_id, Otel.LoggerHandler, %{})

    on_exit(fn -> :logger.remove_handler(@handler_id) end)
    :ok
  end

  describe "baseline + severity" do
    test "1: :info baseline lands as a Loki line with INFO severity",
         %{e2e_id: e2e_id} do
      body = "scenario-1-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      [line] = Loki.lines(results)
      assert line == body
      assert Loki.labels(results)["severity_text"] == "info"
    end

    test "2: each of the 8 :logger levels round-trips with its severity_text label",
         %{e2e_id: e2e_id} do
      levels = [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

      for level <- levels do
        :logger.log(level, "scenario-2-#{level}-#{e2e_id}", %{"e2e.id": e2e_id})
      end

      flush()

      for level <- levels do
        body = "scenario-2-#{level}-#{e2e_id}"
        assert {:ok, results} = poll(Loki.query(body))
        labels = Loki.labels(results)
        # Erlang `:logger` levels round-trip lowercase via the
        # bridge; verify each level's severity_text matches.
        assert labels["severity_text"] == Atom.to_string(level),
               "level #{level}: expected severity_text=#{level}, got #{inspect(labels["severity_text"])}"
      end
    end
  end

  describe "metadata + msg shapes" do
    test "3: primitive metadata is preserved as a categorized label",
         %{e2e_id: e2e_id} do
      body = "scenario-3-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id, role: "admin"})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      assert Loki.labels(results)["role"] == "admin"
    end

    test "4: report-shaped (map) message renders into the line", %{e2e_id: e2e_id} do
      :logger.log(:info, %{tag: "scenario-4", id: e2e_id}, %{"e2e.id": e2e_id})
      flush()

      # Map reports render via :logger's default formatter; the
      # rendered line carries both the tag and id values.
      assert {:ok, results} = poll(Loki.query("scenario-4"))
      line = matching_line(results, "scenario-4", e2e_id)
      assert line =~ "scenario-4"
      assert line =~ e2e_id
    end

    test "5: report-shaped (keyword) message renders into the line",
         %{e2e_id: e2e_id} do
      :logger.log(:info, [tag: "scenario-5", id: e2e_id], %{"e2e.id": e2e_id})
      flush()

      assert {:ok, results} = poll(Loki.query("scenario-5"))
      line = matching_line(results, "scenario-5", e2e_id)
      assert line =~ "scenario-5"
      assert line =~ e2e_id
    end

    test "6: {format, args} msg shape — args interpolated into the rendered line",
         %{e2e_id: e2e_id} do
      :logger.log(:info, {~c"scenario-6 ~ts", [e2e_id]}, %{"e2e.id": e2e_id})
      flush()

      body = "scenario-6 #{e2e_id}"
      assert {:ok, results} = poll(Loki.query(body))
      [line] = Loki.lines(results)
      assert line == body
    end

    test "7: report_cb/1 produces the rendered body", %{e2e_id: e2e_id} do
      cb = fn report -> {~c"scenario-7-cb1 ~ts", [report[:id]]} end
      :logger.log(:info, %{id: e2e_id}, %{report_cb: cb, "e2e.id": e2e_id})
      flush()

      body = "scenario-7-cb1 #{e2e_id}"
      assert {:ok, results} = poll(Loki.query(body))
      [line] = Loki.lines(results)
      assert line == body
    end

    test "8: report_cb/2 produces the rendered body", %{e2e_id: e2e_id} do
      cb = fn report, _opts -> "scenario-8-cb2-#{report[:id]}" end
      :logger.log(:info, %{id: e2e_id}, %{report_cb: cb, "e2e.id": e2e_id})
      flush()

      body = "scenario-8-cb2-#{e2e_id}"
      assert {:ok, results} = poll(Loki.query(body))
      [line] = Loki.lines(results)
      assert line == body
    end
  end

  describe "value coercion" do
    test "9: atom metadata value is coerced to a string label", %{e2e_id: e2e_id} do
      body = "scenario-9-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id, role: :admin})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      # `:admin` must arrive as the string "admin", not "atom"
      # or ":admin".
      assert Loki.labels(results)["role"] == "admin"
    end

    test "10: a struct implementing String.Chars (Date) is rendered into the label",
         %{e2e_id: e2e_id} do
      body = "scenario-10-#{e2e_id}"

      :logger.log(:info, body, %{
        "e2e.id": e2e_id,
        at: ~D[2026-01-01]
      })

      flush()

      assert {:ok, results} = poll(Loki.query(body))
      # `Date.to_string/1` coercion — confirmed by the
      # ISO-formatted value showing up as the `at` label.
      assert Loki.labels(results)["at"] == "2026-01-01"
    end

    test "11: a tuple metadata value is rendered via inspect/1", %{e2e_id: e2e_id} do
      body = "scenario-11-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id, point: {1, 2}})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      # Tuples have no String.Chars implementation, so the bridge
      # falls back to `inspect/1` — `{1, 2}` becomes `"{1, 2}"`.
      assert Loki.labels(results)["point"] == "{1, 2}"
    end
  end

  describe "crash_reason" do
    test "12: exception crash_reason populates exception.* labels",
         %{e2e_id: e2e_id} do
      body = "scenario-12-#{e2e_id}"
      stacktrace = [{__MODULE__, :test, 1, [file: ~c"x", line: 1]}]

      :logger.log(:error, body, %{
        "e2e.id": e2e_id,
        crash_reason: {%RuntimeError{message: "boom-12"}, stacktrace}
      })

      flush()

      assert {:ok, results} = poll(Loki.query(body))
      labels = Loki.labels(results)
      assert labels["exception_type"] =~ "RuntimeError"
      assert labels["exception_message"] == "boom-12"
    end

    test "13: non-exception crash_reason emits the line but leaves exception.* absent",
         %{e2e_id: e2e_id} do
      body = "scenario-13-#{e2e_id}"

      :logger.log(:error, body, %{
        "e2e.id": e2e_id,
        crash_reason: {:shutdown, []}
      })

      flush()

      assert {:ok, results} = poll(Loki.query(body))
      [line] = Loki.lines(results)
      assert line == body
      labels = Loki.labels(results)
      # `:shutdown` is not an Exception — bridge skips
      # exception.* extraction. Negative assertion: those
      # labels MUST be absent.
      refute Map.has_key?(labels, "exception_type")
      refute Map.has_key?(labels, "exception_message")
    end
  end

  describe "code metadata" do
    test "14: mfa metadata maps to code.function.name", %{e2e_id: e2e_id} do
      body = "scenario-14-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id, mfa: {String, :upcase, 1}})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      # `{Module, fun, arity}` formats to "Module.fun/arity"
      # per OTel's code.function.name semconv.
      assert Loki.labels(results)["code_function_name"] == "String.upcase/1"
    end

    test "15: file metadata maps to code.file.path", %{e2e_id: e2e_id} do
      body = "scenario-15-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id, file: ~c"/a/b/c.ex"})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      # Erlang charlist is converted to a string for the label.
      assert Loki.labels(results)["code_file_path"] == "/a/b/c.ex"
    end

    test "16: line metadata maps to code.line.number", %{e2e_id: e2e_id} do
      body = "scenario-16-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id, line: 42})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      assert Loki.labels(results)["code_line_number"] == "42"
    end

    test "17: malformed mfa is silently skipped — line lands, code.function.name absent",
         %{e2e_id: e2e_id} do
      body = "scenario-17-#{e2e_id}"
      :logger.log(:info, body, %{"e2e.id": e2e_id, mfa: :not_a_tuple})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      [line] = Loki.lines(results)
      assert line == body
      # The malformed mfa is dropped — no `code_function_name`
      # label appears (negative assertion).
      labels = Loki.labels(results)
      refute Map.has_key?(labels, "code_function_name")
    end
  end

  describe "domain + reserved keys" do
    test "18: domain metadata maps to log.domain JSON-array label",
         %{e2e_id: e2e_id} do
      body = "scenario-18-#{e2e_id}"
      :logger.log(:info, body, %{domain: [:a, :b], "e2e.id": e2e_id})
      flush()

      assert {:ok, results} = poll(Loki.query(body))
      # The bridge maps `:logger`'s `domain` list to OTel's
      # `log.domain` attribute; otel-lgtm renders array-typed
      # attributes as JSON strings on the label side.
      assert Loki.labels(results)["log_domain"] == ~s(["a","b"])
    end

    test "19: reserved :logger meta keys (time/gl/pid) don't leak as user attributes",
         %{e2e_id: e2e_id} do
      body = "scenario-19-#{e2e_id}"

      :logger.log(:info, body, %{
        "e2e.id": e2e_id,
        time: 0,
        gl: self(),
        pid: self()
      })

      flush()

      assert {:ok, results} = poll(Loki.query(body))
      labels = Loki.labels(results)
      # The reserved keys are intercepted by the bridge — they
      # MUST NOT show up as user-attribute labels (negative
      # assertion).
      refute Map.has_key?(labels, "time")
      refute Map.has_key?(labels, "gl")
      refute Map.has_key?(labels, "pid")
    end
  end

  describe "trace context" do
    test "20: emit inside with_span carries trace_id / span_id labels",
         %{e2e_id: e2e_id} do
      body = "scenario-20-msg-#{e2e_id}"
      span_ctx_ref = make_ref()

      Otel.Trace.with_span(
        "scenario-20-span-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn span_ctx ->
          Process.put(span_ctx_ref, span_ctx)
          :logger.log(:info, body, %{"e2e.id": e2e_id})
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
      # The bridge picks up the active SpanContext at log time.
      assert labels["trace_id"] == expected_trace_id_hex
      assert labels["span_id"] == expected_span_id_hex
    end
  end

  # ---- helpers ----

  # `:logger` map / keyword reports render through the default
  # formatter, which can prefix lines with metadata. Pick the
  # entry whose value contains both anchors.
  @spec matching_line(results :: [map()], anchor1 :: String.t(), anchor2 :: String.t()) ::
          String.t()
  defp matching_line(results, anchor1, anchor2) do
    results
    |> Loki.lines()
    |> Enum.find(&(&1 =~ anchor1 and &1 =~ anchor2))
    |> case do
      nil -> flunk("no line matched both #{inspect(anchor1)} and #{inspect(anchor2)}")
      line -> line
    end
  end
end
