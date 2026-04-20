defmodule Otel.Logger.Handler do
  @moduledoc """
  Bridges Erlang's `:logger` to the OpenTelemetry Logs API.

  Converts log events into OTel LogRecords and emits them via
  `Otel.API.Logs.Logger.emit/3`. When an SDK is installed, log
  records flow through processors to exporters. Without an SDK,
  all emits are no-ops.

  ## Usage

      :logger.add_handler(:otel, Otel.Logger.Handler, %{
        config: %{
          scope_name: "my_app",
          scope_version: "1.0.0"
        }
      })

  ## Configuration

  | Key | Default | Description |
  |---|---|---|
  | `scope_name` | `"otel_logger_handler"` | InstrumentationScope name |
  | `scope_version` | `""` | InstrumentationScope version |
  | `otel_logger` | `nil` | Pre-built OTel Logger; if set, skips `LoggerProvider.get_logger` |

  Batching and export are handled by the SDK's processor pipeline,
  not by this handler. Pair with `BatchProcessor` for production use.
  """

  # --- :logger handler callbacks ---

  @doc false
  @spec adding_handler(config :: :logger.handler_config()) ::
          {:ok, :logger.handler_config()} | {:error, term()}
  def adding_handler(config) do
    otel_config = Map.get(config, :config, %{})

    logger =
      case Map.get(otel_config, :otel_logger) do
        nil ->
          instrumentation_scope = %Otel.API.InstrumentationScope{
            name: Map.get(otel_config, :scope_name, "otel_logger_handler"),
            version: Map.get(otel_config, :scope_version, "")
          }

          Otel.API.Logs.LoggerProvider.get_logger(instrumentation_scope)

        existing ->
          existing
      end

    updated_config = Map.put(config, :config, Map.put(otel_config, :otel_logger, logger))
    {:ok, updated_config}
  end

  @doc false
  @spec removing_handler(config :: :logger.handler_config()) :: :ok
  def removing_handler(_config), do: :ok

  @doc false
  @spec log(log_event :: :logger.log_event(), config :: :logger.handler_config()) :: :ok
  def log(log_event, config) do
    otel_config = Map.get(config, :config, %{})
    logger = Map.get(otel_config, :otel_logger)

    if logger do
      ctx = Otel.API.Ctx.current()
      log_record = build_log_record(log_event)
      Otel.API.Logs.Logger.emit(logger, ctx, log_record)
    end

    :ok
  end

  @doc false
  @spec changing_config(
          set_or_update :: :set | :update,
          old_config :: :logger.handler_config(),
          new_config :: :logger.handler_config()
        ) :: {:ok, :logger.handler_config()} | {:error, term()}
  def changing_config(_set_or_update, _old_config, new_config) do
    {:ok, new_config}
  end

  @doc false
  @spec filter_config(config :: :logger.handler_config()) :: :logger.handler_config()
  def filter_config(config), do: config

  # --- Private ---

  @spec build_log_record(log_event :: :logger.log_event()) ::
          Otel.API.Logs.Logger.log_record()
  defp build_log_record(%{level: level, msg: msg, meta: meta}) do
    %{
      timestamp: extract_timestamp(meta),
      severity_number: severity_number(level),
      severity_text: severity_text(level),
      body: extract_body(msg),
      attributes: extract_attributes(meta)
    }
  end

  @spec extract_timestamp(meta :: map()) :: integer()
  defp extract_timestamp(%{time: time}) do
    time * 1000
  end

  defp extract_timestamp(_meta) do
    System.system_time(:nanosecond)
  end

  @spec extract_body(msg :: term()) :: String.t()
  defp extract_body({:string, string}) do
    IO.chardata_to_string(string)
  end

  defp extract_body({:report, report}) when is_map(report) do
    inspect(report)
  end

  defp extract_body({:report, report}) when is_list(report) do
    inspect(report)
  end

  defp extract_body({format, args}) when is_list(format) do
    :io_lib.format(format, args) |> IO.chardata_to_string()
  end

  defp extract_body(other) do
    inspect(other)
  end

  @spec extract_attributes(meta :: map()) :: map()
  defp extract_attributes(meta) do
    %{}
    |> put_mfa_attrs(meta)
    |> put_meta_attr(meta, :file, "code.filepath", &IO.chardata_to_string/1)
    |> put_meta_attr(meta, :line, "code.lineno", & &1)
    |> put_meta_attr(meta, :pid, "process.pid", &inspect/1)
    |> put_meta_attr(meta, :domain, "log.domain", &inspect/1)
  end

  @spec put_mfa_attrs(attrs :: map(), meta :: map()) :: map()
  defp put_mfa_attrs(attrs, %{mfa: {module, function, arity}}) do
    attrs
    |> Map.put("code.namespace", Atom.to_string(module))
    |> Map.put("code.function", "#{function}/#{arity}")
  end

  defp put_mfa_attrs(attrs, _meta), do: attrs

  @spec put_meta_attr(
          attrs :: map(),
          meta :: map(),
          key :: atom(),
          attr_key :: String.t(),
          transform :: function()
        ) ::
          map()
  defp put_meta_attr(attrs, meta, key, attr_key, transform) do
    case Map.get(meta, key) do
      nil -> attrs
      value -> Map.put(attrs, attr_key, transform.(value))
    end
  end

  # --- Severity mapping ---
  # OTel severity numbers: https://opentelemetry.io/docs/specs/otel/logs/data-model/#severity-fields

  @spec severity_number(level :: :logger.level()) :: 1..24
  defp severity_number(:emergency), do: 21
  defp severity_number(:alert), do: 18
  defp severity_number(:critical), do: 17
  defp severity_number(:error), do: 17
  defp severity_number(:warning), do: 13
  defp severity_number(:notice), do: 12
  defp severity_number(:info), do: 9
  defp severity_number(:debug), do: 5

  @spec severity_text(level :: :logger.level()) :: String.t()
  defp severity_text(:emergency), do: "FATAL"
  defp severity_text(:alert), do: "ERROR3"
  defp severity_text(:critical), do: "ERROR"
  defp severity_text(:error), do: "ERROR"
  defp severity_text(:warning), do: "WARN"
  defp severity_text(:notice), do: "INFO4"
  defp severity_text(:info), do: "INFO"
  defp severity_text(:debug), do: "DEBUG"
end
