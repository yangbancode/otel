defmodule Otel.LoggerHandlerTest.CapturingLogger do
  @moduledoc false
  # Test-double `Otel.API.Logs.Logger` implementation.
  #
  # Forwards every `emit/3` call to the pid it was configured
  # with, so tests can `assert_receive` the exact
  # `log_record` the handler produced. Used in place of the
  # Noop logger the handler would otherwise route to when no
  # SDK is installed — the Noop silently drops records,
  # which prevents us from asserting on their contents.
  #
  # Register as: `{__MODULE__, test_pid}` where `test_pid` is
  # the process that should receive `{:captured_log, ctx,
  # log_record}`.

  @behaviour Otel.API.Logs.Logger

  @impl true
  def emit({__MODULE__, test_pid}, ctx, log_record) do
    send(test_pid, {:captured_log, ctx, log_record})
    :ok
  end

  @impl true
  def enabled?(_logger, _opts), do: true
end

defmodule Otel.LoggerHandlerTest.CapturingProvider do
  @moduledoc false
  # Test-double `Otel.API.Logs.LoggerProvider` implementation.
  #
  # On `get_logger/2`:
  # - sends `{:scope_resolved, scope}` to `test_pid` so tests
  #   can assert on the exact `InstrumentationScope` the handler
  #   built from the flat `scope_*` keys;
  # - returns `{CapturingLogger, test_pid}` so the handler's
  #   downstream `emit/3` is captured back to the same test pid
  #   as `{:captured_log, ctx, log_record}`.
  #
  # Register via
  # `Otel.API.Logs.LoggerProvider.set_provider({__MODULE__, test_pid})`.

  @behaviour Otel.API.Logs.LoggerProvider

  @impl true
  def get_logger(test_pid, %Otel.API.InstrumentationScope{} = scope) do
    send(test_pid, {:scope_resolved, scope})
    {Otel.LoggerHandlerTest.CapturingLogger, test_pid}
  end
end

defmodule Otel.LoggerHandlerTest do
  use ExUnit.Case

  @handler_id :otel_test_handler

  setup do
    :logger.remove_handler(@handler_id)

    # Install the test-double provider so every `log/2`-driven
    # `LoggerProvider.get_logger/1` round-trips through
    # CapturingProvider and lands in CapturingLogger, which
    # relays `:captured_log` back to this test's pid. Each
    # ExUnit test runs in its own process, so `self()` at setup
    # time is the test's pid.
    Otel.API.Logs.LoggerProvider.set_provider({Otel.LoggerHandlerTest.CapturingProvider, self()})

    on_exit(fn ->
      :logger.remove_handler(@handler_id)
      :persistent_term.erase({Otel.API.Logs.LoggerProvider, :global})
    end)

    :ok
  end

  defp handler_config(extra \\ %{}) do
    %{config: Map.merge(%{scope_name: "test_lib"}, extra)}
  end

  # Mirrors `:logger`'s `add_default_metadata/1` (OTP
  # `logger.erl` L1193-L1214), which injects `:time` on every
  # real log call. The handler's `build_log_record/1` pattern
  # match on `%{time: time}` asserts that invariant — tests
  # that don't care about timestamp can still pass `meta: %{}`
  # without crashing, and tests that DO care (microsecond →
  # nanosecond conversion) can still set `:time` explicitly
  # because `Map.put_new/3` is a no-op when the key is present.
  defp log_event(level, msg, meta) do
    meta_with_time = Map.put_new(meta, :time, System.system_time(:microsecond))
    %{level: level, msg: msg, meta: meta_with_time}
  end

  describe "adding_handler/1" do
    test "passes config through unchanged" do
      config = %{config: %{scope_name: "test_lib", scope_version: "1.0.0"}}
      assert {:ok, ^config} = Otel.LoggerHandler.adding_handler(config)
    end

    test "accepts empty :config key" do
      assert {:ok, _} = Otel.LoggerHandler.adding_handler(%{config: %{}})
    end

    test "accepts config with no :config key at all" do
      assert {:ok, _} = Otel.LoggerHandler.adding_handler(%{})
    end
  end

  describe "removing_handler/1" do
    test "returns :ok" do
      assert :ok == Otel.LoggerHandler.removing_handler(%{})
    end
  end

  describe "log/2 — Logger resolution" do
    test "resolves Logger via LoggerProvider on every event" do
      Otel.LoggerHandler.log(
        log_event(:info, {:string, "hi"}, %{time: 1_000_000}),
        handler_config()
      )

      assert_received {:scope_resolved, %Otel.API.InstrumentationScope{name: "test_lib"}}
      assert_received {:captured_log, _ctx, _record}
    end

    test "propagates all four scope_* keys into the InstrumentationScope" do
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, %{}), %{
        config: %{
          scope_name: "my_app",
          scope_version: "2.0.0",
          scope_schema_url: "https://example.com/schemas/1.26.0",
          scope_attributes: %{"deployment.environment" => "test"}
        }
      })

      assert_received {:scope_resolved, scope}
      assert scope.name == "my_app"
      assert scope.version == "2.0.0"
      assert scope.schema_url == "https://example.com/schemas/1.26.0"
      assert scope.attributes == %{"deployment.environment" => "test"}
    end

    test "defaults empty scope_* keys when config is empty" do
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, %{}), %{config: %{}})

      assert_received {:scope_resolved, scope}
      assert scope.name == ""
      assert scope.version == ""
      assert scope.schema_url == ""
      assert scope.attributes == %{}
    end

    test "defaults empty scope_* keys when config has no :config map" do
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, %{}), %{})

      assert_received {:scope_resolved, scope}
      assert scope.name == ""
      assert scope.version == ""
      assert scope.schema_url == ""
      assert scope.attributes == %{}
    end
  end

  # Per `logs/data-model.md` §Mapping of `SeverityNumber`
  # (L273-L296) + Appendix B Syslog row (L806-L818).
  # `SeverityNumber` per Appendix B; `SeverityText` carries
  # the source representation (the `:logger` level atom as a
  # string) per L240-L241 *"original string representation
  # of the severity as it is known at the source"*.
  describe "severity mapping" do
    test ~s|:emergency → 21 / "emergency"| do
      Otel.LoggerHandler.log(log_event(:emergency, {:string, "e"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 21, severity_text: "emergency"}}
    end

    test ~s|:alert → 19 / "alert"| do
      Otel.LoggerHandler.log(log_event(:alert, {:string, "a"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 19, severity_text: "alert"}}
    end

    test ~s|:critical → 18 / "critical"| do
      Otel.LoggerHandler.log(log_event(:critical, {:string, "c"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 18, severity_text: "critical"}}
    end

    test ~s|:error → 17 / "error"| do
      Otel.LoggerHandler.log(log_event(:error, {:string, "err"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 17, severity_text: "error"}}
    end

    test ~s|:warning → 13 / "warning"| do
      Otel.LoggerHandler.log(log_event(:warning, {:string, "w"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 13, severity_text: "warning"}}
    end

    test ~s|:notice → 10 / "notice"| do
      Otel.LoggerHandler.log(log_event(:notice, {:string, "n"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 10, severity_text: "notice"}}
    end

    test ~s|:info → 9 / "info"| do
      Otel.LoggerHandler.log(log_event(:info, {:string, "i"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 9, severity_text: "info"}}
    end

    test ~s|:debug → 5 / "debug"| do
      Otel.LoggerHandler.log(log_event(:debug, {:string, "d"}, %{}), handler_config())
      assert_received {:captured_log, _, %{severity_number: 5, severity_text: "debug"}}
    end
  end

  # Per `logs/data-model.md` §Field: `Body` L399-L400 — Body
  # **MUST** support `AnyValue` to preserve structured-log
  # semantics. `{:report, map}` and `{:report, keyword_list}`
  # are Elixir's structured-log conveyors; the handler must
  # keep the structure instead of `inspect/1`ing it.
  describe "body extraction" do
    test "{:string, chardata} → string" do
      msg = {:string, ["hello ", ~c"world"]}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: "hello world"}}
    end

    # Happy-path policy: malformed input crashes rather than
    # being silently coerced. `IO.chardata_to_string/1` raises
    # `UnicodeConversionError` when chardata contains
    # out-of-range codepoints (e.g. surrogates) or embedded
    # binaries with invalid UTF-8. In production `:logger`'s
    # internal `try/catch` converts the raise into
    # self-healing handler removal.
    #
    # A bare invalid-byte binary (`<<0xFF>>`) does NOT raise
    # — Elixir's `IO.chardata_to_string/1` passes binaries
    # through unchanged without UTF-8 validation. Validation
    # only fires when chardata needs concatenation, e.g.
    # a list containing a surrogate codepoint.
    test "{:string, malformed chardata} raises (happy-path)" do
      # 0xD800 is a UTF-16 surrogate — not a valid Unicode
      # codepoint on its own.
      malformed = [0xD800]

      assert_raise UnicodeConversionError, fn ->
        Otel.LoggerHandler.log(
          log_event(:info, {:string, malformed}, %{}),
          handler_config()
        )
      end
    end

    test "{:report, map} preserves structure as string-keyed map" do
      msg = {:report, %{user_id: 42, action: "login"}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"user_id" => 42, "action" => "login"}
    end

    test "{:report, keyword_list} converts to string-keyed map" do
      msg = {:report, user_id: 42, action: "login"}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"user_id" => 42, "action" => "login"}
    end

    # OTel `map<string, AnyValue>` requires unique keys
    # (`common/README.md` §map L78). `Enum.into(%{})` is our
    # normalising step and yields last-wins on duplicates —
    # the sensible "most-recent" semantics.
    test "{:report, keyword_list} with duplicate keys keeps last value" do
      msg = {:report, [user_id: 1, user_id: 2, user_id: 3]}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"user_id" => 3}
    end

    # `report_cb/1` per OTP `logger.erl` L84 — the caller's
    # explicit rendering declaration. Callback returns
    # `{io:format(), [term()]}`; we format via
    # `:io_lib.format/2`. Supersedes structure preservation
    # because the presence of a callback is an explicit
    # choice to flatten.
    test "{:report, map} with meta.report_cb/1 uses callback's format tuple" do
      report = %{user_id: 42, action: "login"}
      cb = fn r -> {~c"user=~p action=~s", [r.user_id, r.action]} end
      meta = %{report_cb: cb}

      Otel.LoggerHandler.log(log_event(:info, {:report, report}, meta), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == "user=42 action=login"
    end

    # `report_cb/2` per OTP `logger.erl` L85 — callback
    # receives a `report_cb_config()` and returns chardata
    # directly. We pass `depth: :unlimited`,
    # `chars_limit: :unlimited`, `single_line: false` — OTel
    # backends render their own limits (see `## Design notes`).
    test "{:report, map} with meta.report_cb/2 uses callback chardata" do
      report = %{user_id: 42}
      cb = fn r, _config -> ["user=", Integer.to_string(r.user_id)] end
      meta = %{report_cb: cb}

      Otel.LoggerHandler.log(log_event(:info, {:report, report}, meta), handler_config())
      assert_received {:captured_log, _, %{body: "user=42"}}
    end

    # Pins the config shape passed to arity-2 callbacks —
    # OTel wants multi-line preserved and no truncation, so
    # `single_line: false` and `:unlimited` on both depth /
    # chars_limit.
    test "{:report, map} with meta.report_cb/2 receives unlimited, multi-line config" do
      test_pid = self()

      cb = fn _report, config ->
        send(test_pid, {:config_received, config})
        ""
      end

      meta = %{report_cb: cb}

      Otel.LoggerHandler.log(log_event(:info, {:report, %{}}, meta), handler_config())

      assert_received {:config_received,
                       %{depth: :unlimited, chars_limit: :unlimited, single_line: false}}
    end

    # Regression: `LogRecord.body` is typed `primitive_any()`
    # which recursively requires `%{String.t() => ...}` at
    # every nesting level. Prior to recursive stringification,
    # a nested `{:report, %{user: %{id: 42}}}` produced
    # `%{"user" => %{id: 42}}` — OTLP's encoder masked this
    # by re-stringifying on export, but in-process consumers
    # saw mixed-key maps.
    test "{:report, nested map} stringifies keys at every depth" do
      msg = {:report, %{user: %{id: 42, name: "alice"}}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"user" => %{"id" => 42, "name" => "alice"}}
    end

    test "{:report, map with list-of-maps} stringifies keys in all nested maps" do
      msg = {:report, %{events: [%{type: "click"}, %{type: "scroll"}]}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"events" => [%{"type" => "click"}, %{"type" => "scroll"}]}
    end

    # Pins that atom values at any nesting depth go through
    # `String.Chars` (→ `"admin"`, not `:admin` preserved
    # and not `":admin"` from inspect). Guards against a
    # regression where only top-level atom values would be
    # stringified.
    test "{:report, nested map with atom at depth} stringifies atom via String.Chars" do
      msg = {:report, %{user: %{role: :admin}}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"user" => %{"role" => "admin"}}
    end

    # Structs with `String.Chars` impl use `to_string/1` — the
    # protocol IS the user/library declaration of the canonical
    # string form. `Date` renders ISO-8601, not the Elixir sigil
    # literal.
    test "{:report, map with struct impl'ing String.Chars} uses to_string" do
      msg = {:report, %{at: ~D[2024-01-01]}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"at" => "2024-01-01"}
    end

    # Structs without `String.Chars` impl fall back to
    # `inspect/1` — keeps Body AnyValue-clean without
    # flattening the struct.
    test "{:report, map with struct lacking String.Chars} inspects struct" do
      msg = {:report, %{set: MapSet.new([1, 2])}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"set" => "MapSet.new([1, 2])"}
    end

    # Atoms implement `String.Chars`, so `:ok` → `"ok"` (no
    # colon prefix) — friendlier for OTel backend string
    # matching than the Elixir-y `":ok"`.
    test "{:report, map with atom value} uses to_string" do
      msg = {:report, %{status: :ok}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"status" => "ok"}
    end

    # Elixir module atoms are stored internally as
    # `:"Elixir.<Name>"`, and `to_string/1` returns that raw
    # form. Pinned for visibility — the `Elixir.` prefix is
    # accepted as a known trade-off of the `String.Chars`
    # approach.
    test "{:report, map with module atom value} renders with Elixir prefix" do
      msg = {:report, %{service: Enum}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"service" => "Elixir.Enum"}
    end

    # Booleans, `nil`, integers, and floats are `primitive()`
    # per `common.types` — pass through unchanged.
    test "{:report, map with primitive values} preserves them unchanged" do
      msg =
        {:report,
         %{
           active: true,
           deleted: false,
           removed_at: nil,
           count: 42,
           ratio: 0.75
         }}

      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}

      assert body == %{
               "active" => true,
               "deleted" => false,
               "removed_at" => nil,
               "count" => 42,
               "ratio" => 0.75
             }
    end

    test "{:report, map with tuple value} inspects tuple to string" do
      msg = {:report, %{point: {1, 2}}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"point" => "{1, 2}"}
    end

    # The `{:bytes, binary()}` tag is a primitive — it
    # disambiguates raw bytes from UTF-8 strings for the
    # OTLP encoder (common.types L42-L57) and must pass
    # through unchanged.
    test "{:report, map with {:bytes, binary()} value} preserves byte tag" do
      payload = {:bytes, <<0xCA, 0xFE>>}
      msg = {:report, %{data: payload}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"data" => payload}
    end

    test "{format, args} → :io_lib.format output" do
      msg = {~c"hello ~s", [~c"world"]}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), handler_config())
      assert_received {:captured_log, _, %{body: "hello world"}}
    end
  end

  describe "timestamp extraction" do
    test "uses meta.time (µs) scaled to ns" do
      # meta.time is Erlang `system_time(microsecond)`.
      Otel.LoggerHandler.log(
        log_event(:info, {:string, "t"}, %{time: 1_234}),
        handler_config()
      )

      assert_received {:captured_log, _, %{timestamp: 1_234_000}}
    end
  end

  # Per current semantic-conventions (code registry) — we
  # use `code.function.name`, `code.file.path`,
  # `code.line.number`. The deprecated `code.namespace` /
  # `code.function` / `code.filepath` / `code.lineno` keys
  # are intentionally **not** emitted.
  describe "attribute extraction" do
    test "maps mfa to code.function.name as fully-qualified name" do
      meta = %{mfa: {MyModule, :my_func, 2}}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), handler_config())
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.function.name"] == "MyModule.my_func/2"
      refute Map.has_key?(attrs, "code.namespace")
      refute Map.has_key?(attrs, "code.function")
    end

    test "maps file to code.file.path (chardata → string)" do
      meta = %{file: ~c"lib/foo.ex"}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), handler_config())
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.file.path"] == "lib/foo.ex"
      refute Map.has_key?(attrs, "code.filepath")
    end

    test "maps line to code.line.number" do
      meta = %{line: 42}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), handler_config())
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.line.number"] == 42
      refute Map.has_key?(attrs, "code.lineno")
    end

    test "maps domain to log.domain" do
      meta = %{domain: [:elixir, :foo]}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), handler_config())
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["log.domain"] == "[:elixir, :foo]"
    end

    test "omits code.* keys when mfa/file/line absent" do
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, %{}), handler_config())
      assert_received {:captured_log, _, %{attributes: attrs}}
      refute Map.has_key?(attrs, "code.function.name")
      refute Map.has_key?(attrs, "code.file.path")
      refute Map.has_key?(attrs, "code.line.number")
    end

    test "does not emit process.pid even when pid is in meta" do
      # `process.pid` in semconv is an int-typed OS PID;
      # Erlang PIDs don't fit, so we drop rather than
      # mis-represent.
      meta = %{pid: self()}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), handler_config())
      assert_received {:captured_log, _, %{attributes: attrs}}
      refute Map.has_key?(attrs, "process.pid")
    end
  end

  # Per `trace/exceptions.md` §Attributes L44-L55 — crashes
  # routed through `:logger` with `meta.crash_reason = {exc,
  # stack}` should surface as OTel exception events.
  describe "crash_reason extraction" do
    test "populates log_record.exception from meta.crash_reason" do
      exception = %RuntimeError{message: "boom"}
      stacktrace = [{__MODULE__, :test, 0, []}]
      meta = %{crash_reason: {exception, stacktrace}}

      Otel.LoggerHandler.log(log_event(:error, {:string, "crash"}, meta), handler_config())
      assert_received {:captured_log, _, %{exception: captured}}
      assert captured == exception
    end

    test "leaves exception field nil when crash_reason absent" do
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, %{}), handler_config())
      assert_received {:captured_log, _, record}
      assert record.exception == nil
    end

    test "ignores non-exception crash_reason shapes (e.g. exit tuples)" do
      # OTP can also set `crash_reason` to `{:exit, term}`
      # for non-exception exits; those don't fit
      # `Exception.t()` so we drop rather than mis-populate.
      meta = %{crash_reason: {:shutdown, :some_reason}}
      Otel.LoggerHandler.log(log_event(:error, {:string, "x"}, meta), handler_config())
      assert_received {:captured_log, _, record}
      assert record.exception == nil
    end
  end

  describe "integration with :logger" do
    test "handler registers and receives logs without crashing" do
      :ok =
        :logger.add_handler(@handler_id, Otel.LoggerHandler, %{
          config: %{scope_name: "integration_test"}
        })

      :logger.info("integration test message")
      :logger.warning("warning message")
      :logger.error("error message")
    end
  end

  describe "changing_config/3" do
    test "returns {:ok, new_config}" do
      assert {:ok, %{new: true}} ==
               Otel.LoggerHandler.changing_config(:set, %{old: true}, %{new: true})
    end
  end

  describe "filter_config/1" do
    test "returns config unchanged" do
      config = %{config: %{scope_name: "test"}}
      assert config == Otel.LoggerHandler.filter_config(config)
    end
  end
end
