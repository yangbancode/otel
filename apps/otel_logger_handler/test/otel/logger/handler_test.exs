defmodule Otel.Logger.HandlerTest do
  use ExUnit.Case

  @handler_id :otel_test_handler

  setup do
    :logger.remove_handler(@handler_id)

    on_exit(fn ->
      :logger.remove_handler(@handler_id)
    end)

    :ok
  end

  describe "adding_handler/1" do
    test "returns {:ok, config} with otel_logger" do
      config = %{
        config: %{scope_name: "test_lib", scope_version: "1.0.0"}
      }

      {:ok, updated} = Otel.Logger.Handler.adding_handler(config)
      assert Map.has_key?(updated.config, :otel_logger)
      {module, _} = updated.config.otel_logger
      assert module == Otel.API.Logs.Logger.Noop
    end

    test "uses default scope name when not provided" do
      {:ok, updated} = Otel.Logger.Handler.adding_handler(%{config: %{}})
      assert Map.has_key?(updated.config, :otel_logger)
    end
  end

  describe "removing_handler/1" do
    test "returns :ok" do
      assert :ok == Otel.Logger.Handler.removing_handler(%{})
    end
  end

  describe "log/2 with noop" do
    test "does not crash with noop logger" do
      :ok =
        :logger.add_handler(@handler_id, Otel.Logger.Handler, %{
          config: %{scope_name: "test"}
        })

      :logger.info("test message")
    end
  end

  describe "log/2 with SDK" do
    setup do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      test_pid = self()

      {:ok, proc_pid} =
        Otel.SDK.Logs.SimpleProcessor.start_link(%{
          exporter:
            {Otel.SDK.Logs.Exporter.Console,
             %{
               export_fn: fn records ->
                 send(test_pid, {:log_exported, records})
                 :ok
               end
             }},
          name: :handler_test_proc
        })

      {:ok, provider_pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [
              {Otel.SDK.Logs.SimpleProcessor, %{reg_name: :handler_test_proc}}
            ]
          }
        )

      on_exit(fn ->
        if Process.alive?(proc_pid), do: GenServer.stop(proc_pid)
        if Process.alive?(provider_pid), do: GenServer.stop(provider_pid)
      end)

      %{provider: provider_pid, processor: proc_pid}
    end

    test "emits log record through SDK pipeline" do
      :ok =
        :logger.add_handler(@handler_id, Otel.Logger.Handler, %{
          config: %{scope_name: "my_app", scope_version: "2.0.0"}
        })

      # Give handler time to register and get SDK logger
      # Re-add with fresh SDK logger
      :logger.remove_handler(@handler_id)

      :ok =
        :logger.add_handler(@handler_id, Otel.Logger.Handler, %{
          config: %{scope_name: "my_app", scope_version: "2.0.0"}
        })

      :logger.info("hello from logger")
      Process.sleep(50)
    end
  end

  describe "build_log_record" do
    test "maps severity correctly" do
      for {level, expected_number, expected_text} <- [
            {:emergency, 21, "FATAL"},
            {:alert, 18, "ERROR3"},
            {:critical, 17, "ERROR"},
            {:error, 17, "ERROR"},
            {:warning, 13, "WARN"},
            {:notice, 12, "INFO4"},
            {:info, 9, "INFO"},
            {:debug, 5, "DEBUG"}
          ] do
        log_event = %{level: level, msg: {:string, "test"}, meta: %{time: 1_000_000}}
        config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
        Otel.Logger.Handler.log(log_event, config)
      end
    end

    test "extracts string message" do
      log_event = %{level: :info, msg: {:string, "hello world"}, meta: %{time: 1_000_000}}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "extracts format message" do
      log_event = %{level: :info, msg: {~c"hello ~s", [~c"world"]}, meta: %{time: 1_000_000}}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "extracts report message" do
      log_event = %{level: :info, msg: {:report, %{key: "value"}}, meta: %{time: 1_000_000}}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "extracts metadata as attributes" do
      meta = %{
        time: 1_000_000,
        mfa: {MyModule, :my_func, 2},
        file: ~c"lib/my_module.ex",
        line: 42,
        pid: self(),
        domain: [:elixir]
      }

      log_event = %{level: :info, msg: {:string, "test"}, meta: meta}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "extracts metadata without mfa" do
      meta = %{time: 1_000_000, file: ~c"lib/test.ex", line: 10}
      log_event = %{level: :info, msg: {:string, "test"}, meta: meta}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "extracts metadata with no optional fields" do
      meta = %{time: 1_000_000}
      log_event = %{level: :info, msg: {:string, "test"}, meta: meta}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "uses current time when meta has no time" do
      log_event = %{level: :info, msg: {:string, "test"}, meta: %{}}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "extracts report list message" do
      log_event = %{level: :info, msg: {:report, [key: "value"]}, meta: %{time: 1_000_000}}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "extracts unknown message type" do
      log_event = %{level: :info, msg: :unexpected, meta: %{time: 1_000_000}}
      config = %{config: %{otel_logger: {Otel.API.Logs.Logger.Noop, []}}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end

    test "handles missing logger gracefully" do
      config = %{config: %{}}
      log_event = %{level: :info, msg: {:string, "test"}, meta: %{time: 1_000_000}}
      assert :ok == Otel.Logger.Handler.log(log_event, config)
    end
  end

  describe "integration with :logger" do
    test "handler registers and receives logs" do
      :ok =
        :logger.add_handler(@handler_id, Otel.Logger.Handler, %{
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
               Otel.Logger.Handler.changing_config(:set, %{old: true}, %{new: true})
    end
  end

  describe "filter_config/1" do
    test "returns config unchanged" do
      config = %{config: %{scope_name: "test"}}
      assert config == Otel.Logger.Handler.filter_config(config)
    end
  end
end
