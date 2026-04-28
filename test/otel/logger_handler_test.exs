defmodule Otel.LoggerHandlerTest.CapturingLogger do
  @moduledoc false
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
    Otel.API.Logs.LoggerProvider.set_provider({Otel.LoggerHandlerTest.CapturingProvider, self()})

    on_exit(fn ->
      :logger.remove_handler(@handler_id)
      :persistent_term.erase({Otel.API.Logs.LoggerProvider, :global})
    end)

    :ok
  end

  defp emit(level, msg, meta \\ %{}, config \\ %{scope_name: "test_lib"}) do
    # Mirrors `:logger`'s add_default_metadata/1 (OTP logger.erl L1193-L1214).
    meta = Map.put_new(meta, :time, System.system_time(:microsecond))
    Otel.LoggerHandler.log(%{level: level, msg: msg, meta: meta}, %{config: config})
  end

  describe "lifecycle callbacks" do
    test "adding_handler/1 passes config through unchanged; accepts empty / no :config" do
      config = %{config: %{scope_name: "test_lib", scope_version: "1.0.0"}}
      assert {:ok, ^config} = Otel.LoggerHandler.adding_handler(config)
      assert {:ok, _} = Otel.LoggerHandler.adding_handler(%{config: %{}})
      assert {:ok, _} = Otel.LoggerHandler.adding_handler(%{})
    end

    test "removing_handler/1 returns :ok" do
      assert :ok == Otel.LoggerHandler.removing_handler(%{})
    end

    test "changing_config/3 returns {:ok, new}" do
      assert {:ok, %{new: true}} ==
               Otel.LoggerHandler.changing_config(:set, %{old: true}, %{new: true})
    end

    test "filter_config/1 returns config unchanged" do
      config = %{config: %{scope_name: "test"}}
      assert config == Otel.LoggerHandler.filter_config(config)
    end
  end

  describe "log/2 — Logger resolution" do
    test "resolves Logger via LoggerProvider; propagates all four scope_* keys" do
      emit(:info, {:string, "hi"}, %{}, %{
        scope_name: "my_app",
        scope_version: "2.0.0",
        scope_schema_url: "https://example.com/schemas/1.26.0",
        scope_attributes: %{"deployment.environment" => "test"}
      })

      assert_received {:scope_resolved, scope}
      assert scope.name == "my_app"
      assert scope.version == "2.0.0"
      assert scope.schema_url == "https://example.com/schemas/1.26.0"
      assert scope.attributes == %{"deployment.environment" => "test"}

      assert_received {:captured_log, _, _}
    end

    test "defaults empty scope_* keys when config map is empty or missing" do
      for config <- [%{}, nil] do
        message = %{level: :info, msg: {:string, "x"}, meta: %{time: 1}}
        wrapper = if(config, do: %{config: config}, else: %{})
        Otel.LoggerHandler.log(message, wrapper)

        assert_received {:scope_resolved, scope}
        assert scope.name == ""
        assert scope.version == ""
        assert scope.schema_url == ""
        assert scope.attributes == %{}
      end
    end
  end

  # Per `logs/data-model.md` §Mapping of `SeverityNumber`
  # (L273-L296) + Appendix B Syslog row (L806-L818). `severity_text`
  # carries the source representation per L240-L241.
  test "severity mapping for all eight OTP levels" do
    for {level, num, text} <- [
          {:emergency, 21, "emergency"},
          {:alert, 19, "alert"},
          {:critical, 18, "critical"},
          {:error, 17, "error"},
          {:warning, 13, "warning"},
          {:notice, 10, "notice"},
          {:info, 9, "info"},
          {:debug, 5, "debug"}
        ] do
      emit(level, {:string, "x"})
      assert_received {:captured_log, _, record}
      assert record.severity_number == num
      assert record.severity_text == text
    end
  end

  test "timestamp: meta.time (µs) scaled to ns" do
    emit(:info, {:string, "t"}, %{time: 1_234})
    assert_received {:captured_log, _, %{timestamp: 1_234_000}}
  end

  # Per `logs/data-model.md` §Field: `Body` L399-L400 — Body MUST
  # support `AnyValue`. `{:report, _}` keeps structure; `:report_cb`
  # supersedes via OTP `logger.erl` L84-L85.
  describe "body extraction" do
    test "{:string, chardata} → string; malformed chardata raises (happy-path)" do
      emit(:info, {:string, ["hello ", ~c"world"]})
      assert_received {:captured_log, _, %{body: "hello world"}}

      assert_raise UnicodeConversionError, fn ->
        emit(:info, {:string, [0xD800]})
      end
    end

    test "{:report, map} and {:report, keyword_list} → string-keyed map; dup keys last-wins" do
      emit(:info, {:report, %{user_id: 42, action: "login"}})
      assert_received {:captured_log, _, %{body: %{"user_id" => 42, "action" => "login"}}}

      emit(:info, {:report, user_id: 42, action: "login"})
      assert_received {:captured_log, _, %{body: %{"user_id" => 42, "action" => "login"}}}

      # OTel `map<string, AnyValue>` requires unique keys (common/README.md §map L78).
      emit(:info, {:report, [user_id: 1, user_id: 2, user_id: 3]})
      assert_received {:captured_log, _, %{body: %{"user_id" => 3}}}
    end

    test "report_cb/1 and report_cb/2 supersede structure preservation" do
      cb1 = fn r -> {~c"user=~p action=~s", [r.user_id, r.action]} end
      emit(:info, {:report, %{user_id: 42, action: "login"}}, %{report_cb: cb1})
      assert_received {:captured_log, _, %{body: "user=42 action=login"}}

      cb2 = fn r, _config -> ["user=", Integer.to_string(r.user_id)] end
      emit(:info, {:report, %{user_id: 42}}, %{report_cb: cb2})
      assert_received {:captured_log, _, %{body: "user=42"}}
    end

    test "report_cb/2 receives unlimited, multi-line config" do
      test_pid = self()

      cb = fn _report, config ->
        send(test_pid, {:config_received, config})
        ""
      end

      emit(:info, {:report, %{}}, %{report_cb: cb})

      assert_received {:config_received,
                       %{depth: :unlimited, chars_limit: :unlimited, single_line: false}}
    end

    test "{:report, nested} stringifies keys at every depth; preserves list-of-maps" do
      emit(:info, {:report, %{user: %{id: 42, name: "alice"}}})
      assert_received {:captured_log, _, %{body: body1}}
      assert body1 == %{"user" => %{"id" => 42, "name" => "alice"}}

      emit(:info, {:report, %{events: [%{type: "click"}, %{type: "scroll"}]}})
      assert_received {:captured_log, _, %{body: body2}}
      assert body2 == %{"events" => [%{"type" => "click"}, %{"type" => "scroll"}]}
    end

    test "report value coercion: atom→String.Chars; struct uses String.Chars or inspect; primitives passthrough" do
      emit(:info, {:report, %{user: %{role: :admin}}})
      assert_received {:captured_log, _, %{body: %{"user" => %{"role" => "admin"}}}}

      emit(:info, {:report, %{at: ~D[2024-01-01]}})
      assert_received {:captured_log, _, %{body: %{"at" => "2024-01-01"}}}

      emit(:info, {:report, %{set: MapSet.new([1, 2])}})
      assert_received {:captured_log, _, %{body: %{"set" => "MapSet.new([1, 2])"}}}

      # Atom uses `to_string` (no colon prefix); module atoms keep `Elixir.` prefix.
      emit(:info, {:report, %{status: :ok, service: Enum}})

      assert_received {:captured_log, _, %{body: %{"status" => "ok", "service" => "Elixir.Enum"}}}

      emit(
        :info,
        {:report,
         %{active: true, deleted: false, removed_at: nil, count: 42, ratio: 0.75, point: {1, 2}}}
      )

      assert_received {:captured_log, _, %{body: body}}

      assert body == %{
               "active" => true,
               "deleted" => false,
               "removed_at" => nil,
               "count" => 42,
               "ratio" => 0.75,
               "point" => "{1, 2}"
             }
    end

    test "{:bytes, binary()} value preserved as primitive in report body" do
      payload = {:bytes, <<0xCA, 0xFE>>}
      emit(:info, {:report, %{data: payload}})
      assert_received {:captured_log, _, %{body: %{"data" => ^payload}}}
    end

    test "{format, args} → :io_lib.format" do
      emit(:info, {~c"hello ~s", [~c"world"]})
      assert_received {:captured_log, _, %{body: "hello world"}}
    end
  end

  # Per current semantic-conventions registry — `code.function.name`,
  # `code.file.path`, `code.line.number`. Deprecated keys MUST NOT
  # be emitted.
  describe "attribute extraction (semconv-mapped)" do
    test "mfa / file / line → code.function.name / code.file.path / code.line.number" do
      emit(:info, {:string, "x"}, %{
        mfa: {MyModule, :my_func, 2},
        file: ~c"lib/foo.ex",
        line: 42
      })

      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.function.name"] == "MyModule.my_func/2"
      assert attrs["code.file.path"] == "lib/foo.ex"
      assert attrs["code.line.number"] == 42

      for old <- ["code.namespace", "code.function", "code.filepath", "code.lineno"] do
        refute Map.has_key?(attrs, old)
      end
    end

    # Regression for PR #255 — silent-skip on malformed mfa.
    test "malformed mfa silently skips code.function.name" do
      emit(:info, {:string, "x"}, %{mfa: :not_a_tuple})
      assert_received {:captured_log, _, %{attributes: attrs}}
      refute Map.has_key?(attrs, "code.function.name")
    end

    test "domain → log.domain as String array (not inspect-flattened)" do
      emit(:info, {:string, "x"}, %{domain: [:elixir, :foo]})
      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["log.domain"] == ["elixir", "foo"]
    end

    test "absent metadata → no code.* / no process.pid" do
      # Erlang PIDs don't fit semconv's int-typed `process.pid`.
      emit(:info, {:string, "x"}, %{pid: self()})
      assert_received {:captured_log, _, %{attributes: attrs}}
      refute Map.has_key?(attrs, "code.function.name")
      refute Map.has_key?(attrs, "code.file.path")
      refute Map.has_key?(attrs, "code.line.number")
      refute Map.has_key?(attrs, "process.pid")
    end
  end

  # Non-reserved meta keys flow through as custom attributes per
  # spec common/README.md L187 (AnyValue).
  describe "user metadata pass-through" do
    test "primitives / {:bytes, _} preserved verbatim" do
      payload = {:bytes, <<0xCA, 0xFE>>}

      emit(:info, {:string, "x"}, %{
        request_id: "req-abc-123",
        user_id: 42,
        ratio: 0.75,
        active: true,
        deleted_at: nil,
        data: payload
      })

      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["request_id"] == "req-abc-123"
      assert attrs["user_id"] == 42
      assert attrs["ratio"] == 0.75
      assert attrs["active"] == true
      assert Map.has_key?(attrs, "deleted_at") and attrs["deleted_at"] == nil
      assert attrs["data"] == payload
    end

    test "atom / struct (with/without String.Chars) / tuple coerce as expected" do
      emit(:info, {:string, "x"}, %{
        status: :ok,
        at: ~D[2024-01-01],
        set: MapSet.new([1, 2]),
        point: {1, 2}
      })

      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["status"] == "ok"
      assert attrs["at"] == "2024-01-01"
      assert attrs["set"] == "MapSet.new([1, 2])"
      assert attrs["point"] == "{1, 2}"
    end

    # spec common/README.md L187 / L260-L274 — nested AnyValue allowed.
    test "nested map / heterogeneous list / list-of-primitives / list-of-atoms preserved" do
      emit(:info, {:string, "x"}, %{
        detail: %{a: 1, b: "two"},
        items: [1, "a", :x, %{k: "v"}],
        tags: ["alpha", "beta", "gamma"],
        roles: [:admin, :editor]
      })

      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["detail"] == %{"a" => 1, "b" => "two"}
      assert attrs["items"] == [1, "a", "x", %{"k" => "v"}]
      assert attrs["tags"] == ["alpha", "beta", "gamma"]
      assert attrs["roles"] == ["admin", "editor"]
    end

    test "reserved OTP keys (gl / time / report_cb / crash_reason) never leak as attributes" do
      emit(:info, {:string, "x"}, %{
        gl: self(),
        report_cb: fn _ -> "" end,
        crash_reason: {%RuntimeError{message: "boom"}, []}
      })

      assert_received {:captured_log, _, %{attributes: attrs}}
      for k <- ["gl", "time", "report_cb", "crash_reason"], do: refute(Map.has_key?(attrs, k))
    end

    test "user meta coexists with semconv-mapped keys; raw atom keys do not leak" do
      emit(:info, {:string, "x"}, %{
        mfa: {MyMod, :fun, 1},
        file: ~c"lib/my_mod.ex",
        line: 42,
        request_id: "abc"
      })

      assert_received {:captured_log, _, %{attributes: attrs}}
      assert attrs["code.function.name"] == "MyMod.fun/1"
      assert attrs["code.file.path"] == "lib/my_mod.ex"
      assert attrs["code.line.number"] == 42
      assert attrs["request_id"] == "abc"
      for k <- ["mfa", "file", "line"], do: refute(Map.has_key?(attrs, k))
    end
  end

  # Per `trace/exceptions.md` §Attributes L44-L55.
  describe "crash_reason extraction" do
    test "exception sidecar + exception.stacktrace attribute populated when present" do
      exception = %RuntimeError{message: "boom"}
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 42]}]

      emit(:error, {:string, "crash"}, %{crash_reason: {exception, stacktrace}})
      assert_received {:captured_log, _, record}
      assert record.exception == exception
      assert record.attributes["exception.stacktrace"] == Exception.format_stacktrace(stacktrace)
    end

    test "absent crash_reason / non-exception shape → nil exception, no stacktrace attribute" do
      emit(:info, {:string, "x"})
      assert_received {:captured_log, _, record}
      assert record.exception == nil
      refute Map.has_key?(record.attributes, "exception.stacktrace")

      emit(:error, {:string, "x"}, %{crash_reason: {:shutdown, :some_reason}})
      assert_received {:captured_log, _, record}
      assert record.exception == nil
      refute Map.has_key?(record.attributes, "exception.stacktrace")
    end
  end

  test "integration — handler registers under :logger and routes calls without crashing" do
    :ok =
      :logger.add_handler(@handler_id, Otel.LoggerHandler, %{
        config: %{scope_name: "integration_test"}
      })

    :logger.info("integration test message")
    :logger.warning("warning message")
    :logger.error("error message")
  end
end
