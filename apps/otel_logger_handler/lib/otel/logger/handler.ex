defmodule Otel.Logger.Handler do
  @moduledoc """
  Bridges Erlang's `:logger` to the OpenTelemetry Logs API
  (OTel `logs/api.md` + `logs/supplementary-guidelines.md`
  §How to Create a Log4J Log Appender).

  Converts `:logger.log_event/0` into an
  `Otel.API.Logs.Logger.log_record/0` and emits it via
  `Otel.API.Logs.Logger.emit/3`. When an SDK is installed,
  records flow through processors to exporters; without an
  SDK, `emit/3` routes to `Otel.API.Logs.Logger.Noop` and
  becomes a silent no-op.

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

  Batching and export are handled by the SDK's processor
  pipeline, not by this handler. Pair with `BatchProcessor`
  for production use.

  ## Severity mapping

  Maps `:logger` levels — which are the lowercased
  RFC 5424 Syslog levels — to OTel `SeverityNumber` per
  `logs/data-model.md` §Mapping of `SeverityNumber` (L273-L296)
  and the Syslog row of Appendix B (L806-L818):

  | `:logger` level | SeverityNumber | Short name |
  |---|---|---|
  | `:emergency` | 21 | FATAL |
  | `:alert` | 19 | ERROR3 |
  | `:critical` | 18 | ERROR2 |
  | `:error` | 17 | ERROR |
  | `:warning` | 13 | WARN |
  | `:notice` | 10 | INFO2 |
  | `:info` | 9 | INFO |
  | `:debug` | 5 | DEBUG |

  `SeverityText` currently carries the OTel short-name form
  (`"FATAL"`, `"ERROR3"`, …); migrating it to the source
  representation (`"emergency"`, `"alert"`, …) per
  `logs/data-model.md` L240-L241 *"original string
  representation of the severity as it is known at the
  source"* is deferred to a follow-up refactor.

  ## Body extraction

  Per `logs/data-model.md` §Field: `Body` L399-L400, Body
  **MUST** support `AnyValue` to preserve the semantics of
  structured logs. Elixir `:logger`'s `{:report, term}`
  carries structured data, so we preserve the structure
  instead of collapsing to a string:

  | `msg` shape | Body |
  |---|---|
  | `{:string, chardata}` | `IO.chardata_to_string/1` |
  | `{:report, map}` | map with string keys |
  | `{:report, keyword_list}` | map derived from the keyword list |
  | `{format, args}` (`:io_lib.format/2` shape) | formatted string |
  | anything else | `inspect/1` fallback |

  ## Exception events

  Erlang/OTP routes crashes through `:logger` with
  `meta.crash_reason = {exception, stacktrace}`. We surface
  this on the `log_record` via the `:exception` field
  (`Otel.API.Logs.Logger.log_record/0`), which lets
  downstream processing populate the OTel
  `exception.*` attributes per `trace/exceptions.md`
  §Attributes L44-L55.

  ## Attribute mapping

  `meta` fields map to OTel attribute keys per the
  [semantic conventions](https://github.com/open-telemetry/semantic-conventions)
  `code.*` registry. The deprecated `code.namespace` /
  `code.function` / `code.filepath` / `code.lineno` keys are
  not emitted; we use the current stable names:

  | `:logger` meta | OTel attribute | Notes |
  |---|---|---|
  | `mfa: {module, fun, arity}` | `code.function.name` | `"Module.fun/arity"` fully-qualified form |
  | `file: chardata` | `code.file.path` | |
  | `line: integer` | `code.line.number` | |
  | `domain: [atom]` | `log.domain` | non-standard convenience |

  `pid` is intentionally **not** emitted — `process.pid` is
  an int-typed OS PID attribute in semantic-conventions and
  does not fit an Erlang PID (`#PID<0.123.0>`). A follow-up
  decision will settle whether to emit it under a
  BEAM-specific custom key or drop it entirely.
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
    base = %{
      timestamp: extract_timestamp(meta),
      severity_number: severity_number(level),
      severity_text: severity_text(level),
      body: extract_body(msg),
      attributes: extract_attributes(meta)
    }

    put_exception(base, meta)
  end

  @spec extract_timestamp(meta :: map()) :: integer()
  defp extract_timestamp(%{time: time}) do
    time * 1000
  end

  defp extract_timestamp(_meta) do
    System.system_time(:nanosecond)
  end

  # Body extraction — `logs/data-model.md` L399-L400 requires
  # preserving `AnyValue` structure for structured logs.
  # `{:report, term}` is Elixir's structured-log shape; we
  # preserve it as a map rather than collapsing to a string.
  @spec extract_body(msg :: term()) :: term()
  defp extract_body({:string, string}) do
    IO.chardata_to_string(string)
  end

  defp extract_body({:report, report}) when is_map(report) do
    stringify_keys(report)
  end

  defp extract_body({:report, report}) when is_list(report) do
    report |> Enum.into(%{}) |> stringify_keys()
  end

  defp extract_body({format, args}) when is_list(format) do
    :io_lib.format(format, args) |> IO.chardata_to_string()
  end

  defp extract_body(other) do
    inspect(other)
  end

  @spec stringify_keys(map :: map()) :: %{String.t() => term()}
  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  @spec extract_attributes(meta :: map()) :: map()
  defp extract_attributes(meta) do
    %{}
    |> put_code_function_name(meta)
    |> put_meta_attr(meta, :file, "code.file.path", &IO.chardata_to_string/1)
    |> put_meta_attr(meta, :line, "code.line.number", & &1)
    |> put_meta_attr(meta, :domain, "log.domain", &inspect/1)
  end

  # Elixir/OTP `mfa` → `code.function.name` as a
  # fully-qualified `"Module.fun/arity"` string, per the
  # current semantic-conventions guidance that
  # `code.function.name` absorbs what the deprecated
  # `code.namespace` + `code.function` pair used to carry.
  @spec put_code_function_name(attrs :: map(), meta :: map()) :: map()
  defp put_code_function_name(attrs, %{mfa: {module, function, arity}}) do
    Map.put(attrs, "code.function.name", "#{inspect(module)}.#{function}/#{arity}")
  end

  defp put_code_function_name(attrs, _meta), do: attrs

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

  # `meta.crash_reason = {exception, stacktrace}` is OTP's
  # standard way of surfacing process crashes to the log
  # handler. When present, we route it into the
  # `log_record.exception` field so downstream processors /
  # exporters can attach `exception.*` attributes per
  # `trace/exceptions.md` §Attributes L44-L55.
  @spec put_exception(
          log_record :: Otel.API.Logs.Logger.log_record(),
          meta :: map()
        ) :: Otel.API.Logs.Logger.log_record()
  defp put_exception(log_record, %{crash_reason: {%{__exception__: true} = exception, _stack}}) do
    Map.put(log_record, :exception, exception)
  end

  defp put_exception(log_record, _meta), do: log_record

  # Severity mapping — `logs/data-model.md` §Mapping of
  # `SeverityNumber` L273-L296 + Appendix B Syslog row
  # (L806-L818). `:logger` levels are lowercased Syslog
  # levels (RFC 5424).
  @spec severity_number(level :: :logger.level()) :: 1..24
  defp severity_number(:emergency), do: 21
  defp severity_number(:alert), do: 19
  defp severity_number(:critical), do: 18
  defp severity_number(:error), do: 17
  defp severity_number(:warning), do: 13
  defp severity_number(:notice), do: 10
  defp severity_number(:info), do: 9
  defp severity_number(:debug), do: 5

  @spec severity_text(level :: :logger.level()) :: String.t()
  defp severity_text(:emergency), do: "FATAL"
  defp severity_text(:alert), do: "ERROR3"
  defp severity_text(:critical), do: "ERROR2"
  defp severity_text(:error), do: "ERROR"
  defp severity_text(:warning), do: "WARN"
  defp severity_text(:notice), do: "INFO2"
  defp severity_text(:info), do: "INFO"
  defp severity_text(:debug), do: "DEBUG"
end
