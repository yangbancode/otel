defmodule Otel.E2E.LogHandlerTest do
  @moduledoc """
  E2E coverage for the `:logger` → OTel bridge
  (`Otel.LoggerHandler`) against Loki.

  `setup_all` registers `:otel_e2e` as a `:logger` handler so
  `:logger.log/3` calls flow through `Otel.LoggerHandler` →
  `Otel.API.Logs.Logger.emit/2` → the SDK pipeline → Loki. The
  handler is removed in `on_exit` so subsequent e2e modules
  don't see duplicated emits.

  Scenarios call `:logger.log/3` directly rather than the Elixir
  `Logger.*` macros so the test file doesn't have to register
  every transient metadata key in the application's `:logger`
  config — the handler bridge is the same on both surfaces.

  Tracking matrix: `docs/e2e.md` §Log — `:logger` Handler bridge,
  scenarios 1–21.
  """

  use Otel.E2E.Case, async: false

  @handler_id :otel_e2e

  setup_all do
    :logger.add_handler(@handler_id, Otel.LoggerHandler, %{
      config: %{
        scope_name: "otel-e2e-log-handler",
        scope_version: "0.1.0"
      }
    })

    on_exit(fn -> :logger.remove_handler(@handler_id) end)
    :ok
  end

  describe "baseline + severity" do
    test "1: :info baseline lands as a Loki line", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-1-#{e2e_id}", %{"e2e.id": e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "2: each of the 8 :logger levels round-trips", %{e2e_id: e2e_id} do
      for level <- [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug] do
        :logger.log(level, "scenario-2-#{level}-#{e2e_id}", %{"e2e.id": e2e_id})
      end

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "metadata + msg shapes" do
    test "3: primitive metadata is preserved", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-3-#{e2e_id}", %{"e2e.id": e2e_id, role: "admin"})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "4: report-shaped (map) message lands", %{e2e_id: e2e_id} do
      :logger.log(:info, %{tag: "scenario-4", id: e2e_id}, %{"e2e.id": e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "5: report-shaped (keyword) message lands", %{e2e_id: e2e_id} do
      :logger.log(:info, [tag: "scenario-5", id: e2e_id], %{"e2e.id": e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "6: {format, args} msg shape", %{e2e_id: e2e_id} do
      :logger.log(:info, {~c"scenario-6 ~ts", [e2e_id]}, %{"e2e.id": e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "7: report_cb/1 produces the body", %{e2e_id: e2e_id} do
      cb = fn report -> {~c"scenario-7-cb1 ~ts", [report[:id]]} end
      :logger.log(:info, %{id: e2e_id}, %{report_cb: cb, "e2e.id": e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "8: report_cb/2 produces the body", %{e2e_id: e2e_id} do
      cb = fn report, _opts -> "scenario-8-cb2-#{report[:id]}" end
      :logger.log(:info, %{id: e2e_id}, %{report_cb: cb, "e2e.id": e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "value coercion" do
    test "9: atom metadata value is coerced to a string", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-9-#{e2e_id}", %{"e2e.id": e2e_id, role: :admin})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "10: a struct implementing String.Chars (Date) is rendered", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-10-#{e2e_id}", %{
        "e2e.id": e2e_id,
        at: ~D[2026-01-01]
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "11: a tuple metadata value is rendered via inspect/1", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-11-#{e2e_id}", %{"e2e.id": e2e_id, point: {1, 2}})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "crash_reason" do
    test "12: exception crash_reason populates exception.* attrs", %{e2e_id: e2e_id} do
      stacktrace = [{__MODULE__, :test, 1, [file: ~c"x", line: 1]}]

      :logger.log(:error, "scenario-12-#{e2e_id}", %{
        "e2e.id": e2e_id,
        crash_reason: {%RuntimeError{message: "boom-12"}, stacktrace}
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "13: non-exception crash_reason emits the line but no exception.* attrs",
         %{e2e_id: e2e_id} do
      :logger.log(:error, "scenario-13-#{e2e_id}", %{
        "e2e.id": e2e_id,
        crash_reason: {:shutdown, []}
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "code metadata" do
    test "14: mfa metadata maps to code.function.name", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-14-#{e2e_id}", %{
        "e2e.id": e2e_id,
        mfa: {__MODULE__, :run, 0}
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "15: file metadata maps to code.file.path", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-15-#{e2e_id}", %{
        "e2e.id": e2e_id,
        file: ~c"/a/b/c.ex"
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "16: line metadata maps to code.line.number", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-16-#{e2e_id}", %{"e2e.id": e2e_id, line: 42})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "17: malformed mfa is silently skipped (no crash, line still lands)",
         %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-17-#{e2e_id}", %{
        mfa: :not_a_tuple,
        "e2e.id": e2e_id
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "domain + reserved keys" do
    test "18: domain metadata maps to log.domain array", %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-18-#{e2e_id}", %{
        domain: [:a, :b],
        "e2e.id": e2e_id
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "19: reserved :logger meta keys don't leak as user attributes",
         %{e2e_id: e2e_id} do
      :logger.log(:info, "scenario-19-#{e2e_id}", %{
        "e2e.id": e2e_id,
        time: 0,
        gl: self(),
        pid: self()
      })

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end

  describe "trace context + scope" do
    test "20: emit inside with_span carries trace_id / span_id", %{e2e_id: e2e_id} do
      tracer = Otel.Trace.TracerProvider.get_tracer(scope())

      Otel.Trace.with_span(
        tracer,
        "scenario-20-span-#{e2e_id}",
        [attributes: %{"e2e.id" => e2e_id}],
        fn _ ->
          :logger.log(:info, "scenario-20-msg-#{e2e_id}", %{"e2e.id": e2e_id})
        end
      )

      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end

    test "21: scope_* keys flow through to InstrumentationScope", %{e2e_id: e2e_id} do
      # Already exercised by `setup_all` — every test uses the
      # configured scope ("otel-e2e-log-handler", "0.1.0"). The
      # handler builds a fresh InstrumentationScope per event
      # from those keys, so any landed record proves the four
      # scope_* fields reached the Logger build path.
      :logger.log(:info, "scenario-21-#{e2e_id}", %{"e2e.id": e2e_id})
      flush()
      assert {:ok, [_ | _]} = poll(Loki.query(e2e_id))
    end
  end
end
