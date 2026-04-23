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

defmodule Otel.LoggerHandlerTest do
  use ExUnit.Case

  @handler_id :otel_test_handler

  setup do
    :logger.remove_handler(@handler_id)

    on_exit(fn ->
      :logger.remove_handler(@handler_id)
    end)

    # Each test body runs in its own process, so self() at
    # macro-expansion time is stale — rebuild the logger
    # tuple with the actual test pid in a setup block.
    {:ok, logger: {Otel.LoggerHandlerTest.CapturingLogger, self()}}
  end

  defp config_with(logger), do: %{config: %{otel_logger: logger}}

  defp log_event(level, msg, meta) do
    %{level: level, msg: msg, meta: meta}
  end

  describe "adding_handler/1" do
    test "builds a Logger via LoggerProvider when none is pre-configured" do
      config = %{config: %{scope_name: "test_lib", scope_version: "1.0.0"}}

      {:ok, updated} = Otel.LoggerHandler.adding_handler(config)

      assert Map.has_key?(updated.config, :otel_logger)
      {module, _state} = updated.config.otel_logger
      # No SDK installed, so LoggerProvider hands back the Noop.
      assert module == Otel.API.Logs.Logger.Noop
    end

    test "uses default scope name when not provided" do
      {:ok, updated} = Otel.LoggerHandler.adding_handler(%{config: %{}})
      assert Map.has_key?(updated.config, :otel_logger)
    end

    test "preserves pre-configured otel_logger" do
      pre_configured = {SomeFakeModule, %{custom: true}}
      config = %{config: %{otel_logger: pre_configured}}
      {:ok, updated} = Otel.LoggerHandler.adding_handler(config)
      assert updated.config.otel_logger == pre_configured
    end
  end

  describe "removing_handler/1" do
    test "returns :ok" do
      assert :ok == Otel.LoggerHandler.removing_handler(%{})
    end
  end

  describe "log/2 dispatch" do
    test "no-op when config has no otel_logger" do
      event = log_event(:info, {:string, "hi"}, %{time: 1_000_000})
      assert :ok == Otel.LoggerHandler.log(event, %{config: %{}})
      refute_received {:captured_log, _, _}
    end

    test "emits through the configured logger", %{logger: logger} do
      event = log_event(:info, {:string, "hi"}, %{time: 1_000_000})
      Otel.LoggerHandler.log(event, config_with(logger))
      assert_received {:captured_log, _ctx, _record}
    end
  end

  # Per `logs/data-model.md` §Mapping of `SeverityNumber`
  # (L273-L296) + Appendix B Syslog row (L806-L818).
  # `SeverityNumber` per Appendix B; `SeverityText` carries
  # the source representation (the `:logger` level atom as a
  # string) per L240-L241 *"original string representation
  # of the severity as it is known at the source"*.
  describe "severity mapping" do
    test ~s|:emergency → 21 / "emergency"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:emergency, {:string, "e"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 21, severity_text: "emergency"}}
    end

    test ~s|:alert → 19 / "alert"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:alert, {:string, "a"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 19, severity_text: "alert"}}
    end

    test ~s|:critical → 18 / "critical"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:critical, {:string, "c"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 18, severity_text: "critical"}}
    end

    test ~s|:error → 17 / "error"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:error, {:string, "err"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 17, severity_text: "error"}}
    end

    test ~s|:warning → 13 / "warning"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:warning, {:string, "w"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 13, severity_text: "warning"}}
    end

    test ~s|:notice → 10 / "notice"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:notice, {:string, "n"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 10, severity_text: "notice"}}
    end

    test ~s|:info → 9 / "info"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:info, {:string, "i"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 9, severity_text: "info"}}
    end

    test ~s|:debug → 5 / "debug"|, %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:debug, {:string, "d"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{severity_number: 5, severity_text: "debug"}}
    end
  end

  # Per `logs/data-model.md` §Field: `Body` L399-L400 — Body
  # **MUST** support `AnyValue` to preserve structured-log
  # semantics. `{:report, map}` and `{:report, keyword_list}`
  # are Elixir's structured-log conveyors; the handler must
  # keep the structure instead of `inspect/1`ing it.
  describe "body extraction" do
    test "{:string, chardata} → string", %{logger: logger} do
      msg = {:string, ["hello ", ~c"world"]}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), config_with(logger))
      assert_received {:captured_log, _, %{body: "hello world"}}
    end

    test "{:report, map} preserves structure as string-keyed map", %{logger: logger} do
      msg = {:report, %{user_id: 42, action: "login"}}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), config_with(logger))
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"user_id" => 42, "action" => "login"}
    end

    test "{:report, keyword_list} converts to string-keyed map", %{logger: logger} do
      msg = {:report, user_id: 42, action: "login"}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), config_with(logger))
      assert_received {:captured_log, _, %{body: body}}
      assert body == %{"user_id" => 42, "action" => "login"}
    end

    test "{format, args} → :io_lib.format output", %{logger: logger} do
      msg = {~c"hello ~s", [~c"world"]}
      Otel.LoggerHandler.log(log_event(:info, msg, %{}), config_with(logger))
      assert_received {:captured_log, _, %{body: "hello world"}}
    end

    test "unknown shape falls back to inspect/1", %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:info, :unexpected_atom, %{}), config_with(logger))
      assert_received {:captured_log, _, %{body: ":unexpected_atom"}}
    end
  end

  describe "timestamp extraction" do
    test "uses meta.time (µs) scaled to ns", %{logger: logger} do
      # meta.time is Erlang `system_time(microsecond)`.
      Otel.LoggerHandler.log(
        log_event(:info, {:string, "t"}, %{time: 1_234}),
        config_with(logger)
      )

      assert_received {:captured_log, _, %{timestamp: 1_234_000}}
    end

    test "falls back to current time when meta.time absent", %{logger: logger} do
      before = System.system_time(:nanosecond)
      Otel.LoggerHandler.log(log_event(:info, {:string, "t"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{timestamp: ts}}
      assert ts >= before
      assert ts <= System.system_time(:nanosecond)
    end
  end

  # Per current semantic-conventions (code registry) — we
  # use `code.function.name`, `code.file.path`,
  # `code.line.number`. The deprecated `code.namespace` /
  # `code.function` / `code.filepath` / `code.lineno` keys
  # are intentionally **not** emitted.
  describe "attribute extraction" do
    test "maps mfa to code.function.name as fully-qualified name", %{logger: logger} do
      meta = %{mfa: {MyModule, :my_func, 2}}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), config_with(logger))
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.function.name"] == "MyModule.my_func/2"
      refute Map.has_key?(attrs, "code.namespace")
      refute Map.has_key?(attrs, "code.function")
    end

    test "maps file to code.file.path (chardata → string)", %{logger: logger} do
      meta = %{file: ~c"lib/foo.ex"}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), config_with(logger))
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.file.path"] == "lib/foo.ex"
      refute Map.has_key?(attrs, "code.filepath")
    end

    test "maps line to code.line.number", %{logger: logger} do
      meta = %{line: 42}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), config_with(logger))
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.line.number"] == 42
      refute Map.has_key?(attrs, "code.lineno")
    end

    test "maps domain to log.domain", %{logger: logger} do
      meta = %{domain: [:elixir, :foo]}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), config_with(logger))
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["log.domain"] == "[:elixir, :foo]"
    end

    test "omits code.* keys when mfa/file/line absent", %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, %{}), config_with(logger))
      assert_received {:captured_log, _, %{attributes: attrs}}
      refute Map.has_key?(attrs, "code.function.name")
      refute Map.has_key?(attrs, "code.file.path")
      refute Map.has_key?(attrs, "code.line.number")
    end

    test "does not emit process.pid even when pid is in meta", %{logger: logger} do
      # `process.pid` in semconv is an int-typed OS PID;
      # Erlang PIDs don't fit, so we drop rather than
      # mis-represent.
      meta = %{pid: self()}
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, meta), config_with(logger))
      assert_received {:captured_log, _, %{attributes: attrs}}
      refute Map.has_key?(attrs, "process.pid")
    end
  end

  # Per `trace/exceptions.md` §Attributes L44-L55 — crashes
  # routed through `:logger` with `meta.crash_reason = {exc,
  # stack}` should surface as OTel exception events.
  describe "crash_reason extraction" do
    test "populates log_record.exception from meta.crash_reason", %{logger: logger} do
      exception = %RuntimeError{message: "boom"}
      stacktrace = [{__MODULE__, :test, 0, []}]
      meta = %{crash_reason: {exception, stacktrace}}

      Otel.LoggerHandler.log(log_event(:error, {:string, "crash"}, meta), config_with(logger))
      assert_received {:captured_log, _, %{exception: captured}}
      assert captured == exception
    end

    test "leaves exception field nil when crash_reason absent", %{logger: logger} do
      Otel.LoggerHandler.log(log_event(:info, {:string, "x"}, %{}), config_with(logger))
      assert_received {:captured_log, _, record}
      assert record.exception == nil
    end

    test "ignores non-exception crash_reason shapes (e.g. exit tuples)", %{logger: logger} do
      # OTP can also set `crash_reason` to `{:exit, term}`
      # for non-exception exits; those don't fit
      # `Exception.t()` so we drop rather than mis-populate.
      meta = %{crash_reason: {:shutdown, :some_reason}}
      Otel.LoggerHandler.log(log_event(:error, {:string, "x"}, meta), config_with(logger))
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
