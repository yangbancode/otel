defmodule Otel.LoggerHandler do
  @moduledoc """
  Bridges Erlang's `:logger` to the OpenTelemetry Logs API
  (OTel `logs/api.md` + `logs/supplementary-guidelines.md`
  §How to Create a Log4J Log Appender).

  Converts `:logger.log_event/0` into an
  `Otel.API.Logs.LogRecord.t/0` and emits it via
  `Otel.API.Logs.Logger.emit/3`. When an SDK is installed,
  records flow through processors to exporters; without an
  SDK, `emit/3` routes to `Otel.API.Logs.Logger.Noop` and
  becomes a silent no-op.

  ## Usage

      :logger.add_handler(:otel, Otel.LoggerHandler, %{
        config: %{
          scope_name: "my_app",
          scope_version: "1.0.0"
        }
      })

  ## Configuration

  All handler-specific options live under the handler config's
  `:config` key (`:logger.handler_config()` L116-L122). Every
  key is optional.

  | Key | Default | Description |
  |---|---|---|
  | `scope_name` | `""` | `Otel.API.InstrumentationScope.name` — **SHOULD** be set to the calling application/library name. Spec `common/instrumentation-scope.md`: *"Instrumentation libraries SHOULD supply a meaningful name — typically the library's own module path"*. An empty name is spec-valid ("unspecified scope") but loses origin identification at the backend |
  | `scope_version` | `""` | `Otel.API.InstrumentationScope.version` — typically `Application.spec(:my_app, :vsn)` |
  | `scope_schema_url` | `""` | `Otel.API.InstrumentationScope.schema_url` (OTel spec v1.13.0+) |
  | `scope_attributes` | `%{}` | `Otel.API.InstrumentationScope.attributes` (OTEP 0201). Follows OTel attribute rules: primitives or homogeneous arrays only |

  `log/2` builds an `%Otel.API.InstrumentationScope{}` from the
  four `scope_*` keys on every event and resolves the Logger
  through `Otel.API.Logs.LoggerProvider.get_logger/1`. Resolution
  is deliberately done per-event rather than cached at
  `adding_handler/1` time — caching the resolved Logger would
  lock in whatever was registered when the handler was added
  (typically Noop during kernel start-up, before any SDK
  `LoggerProvider.set_provider/1` runs), and every subsequent
  event would silently drop through that stale Noop even after
  the SDK comes up.

  To use a custom Logger implementation (e.g. for testing),
  register a custom `Otel.API.Logs.LoggerProvider` via
  `Otel.API.Logs.LoggerProvider.set_provider/1` — `log/2` will
  obtain the Logger through that provider on every call.

  Batching and export are handled by the SDK's processor
  pipeline, not by this handler. Pair with `BatchProcessor`
  for production use.

  ## Severity mapping

  Maps `:logger` levels — which are the lowercased
  RFC 5424 Syslog levels — to OTel `SeverityNumber` per
  `logs/data-model.md` §Mapping of `SeverityNumber`
  (L273-L296) and the Syslog row of Appendix B
  (`data-model-appendix.md` L806-L818):

  | `:logger` level | SeverityNumber | SeverityText (source) | OTel short name (display) |
  |---|---|---|---|
  | `:emergency` | 21 | `"emergency"` | FATAL |
  | `:alert` | 19 | `"alert"` | ERROR3 |
  | `:critical` | 18 | `"critical"` | ERROR2 |
  | `:error` | 17 | `"error"` | ERROR |
  | `:warning` | 13 | `"warning"` | WARN |
  | `:notice` | 10 | `"notice"` | INFO2 |
  | `:info` | 9 | `"info"` | INFO |
  | `:debug` | 5 | `"debug"` | DEBUG |

  Distinct `:logger` levels within the same SeverityNumber
  range (e.g. `:error` vs `:critical` vs `:alert` in ERROR)
  are assigned different numbers per spec L280-L283,
  preserving their relative ordering.

  `SeverityText` carries the **source representation** of
  the level — the `:logger` level atom rendered as a string
  per `logs/data-model.md` L240-L241 *"original string
  representation of the severity as it is known at the
  source"*. Downstream tooling that wants the OTel short
  name (`"FATAL"`, `"ERROR3"`, …) can derive it from
  `severity_number` using the §Displaying Severity
  L334-L363 table; the short name is a display concern and
  is not what the `SeverityText` field is for.

  The mapping is internal to this module rather than shared
  in `otel_api` — `Otel.API.Logs` owns the two **types**
  (`severity_number/0`, `severity_level/0`) but the
  `:logger`-specific conversion lives where it is consumed.
  Other bridges targeting non-`:logger` sources (e.g. a
  direct Syslog priority number, a `:telemetry` handler)
  define their own conversion the same way.

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
  (`Otel.API.Logs.LogRecord.t/0`), which lets
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
  def adding_handler(config), do: {:ok, config}

  @doc false
  @spec removing_handler(config :: :logger.handler_config()) :: :ok
  def removing_handler(_config), do: :ok

  @doc false
  @spec log(log_event :: :logger.log_event(), config :: :logger.handler_config()) :: :ok
  def log(log_event, config) do
    ctx = Otel.API.Ctx.current()
    instrumentation_scope = build_instrumentation_scope(config)
    logger = Otel.API.Logs.LoggerProvider.get_logger(instrumentation_scope)
    log_record = build_log_record(log_event)
    Otel.API.Logs.Logger.emit(logger, ctx, log_record)
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

  @spec build_instrumentation_scope(config :: :logger.handler_config()) ::
          Otel.API.InstrumentationScope.t()
  defp build_instrumentation_scope(config) do
    otel_config = Map.get(config, :config) || %{}

    %Otel.API.InstrumentationScope{
      name: Map.get(otel_config, :scope_name) || "",
      version: Map.get(otel_config, :scope_version) || "",
      schema_url: Map.get(otel_config, :scope_schema_url) || "",
      attributes: Map.get(otel_config, :scope_attributes) || %{}
    }
  end

  @spec build_log_record(log_event :: :logger.log_event()) ::
          Otel.API.Logs.LogRecord.t()
  defp build_log_record(%{level: level, msg: msg, meta: meta}) do
    base = %Otel.API.Logs.LogRecord{
      timestamp: extract_timestamp(meta),
      severity_number: severity_number(level),
      severity_text: severity_text(level),
      body: extract_body(msg),
      attributes: extract_attributes(meta)
    }

    put_exception(base, meta)
  end

  @spec extract_timestamp(meta :: map()) :: non_neg_integer()
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
          log_record :: Otel.API.Logs.LogRecord.t(),
          meta :: map()
        ) :: Otel.API.Logs.LogRecord.t()
  defp put_exception(log_record, %{crash_reason: {%{__exception__: true} = exception, _stack}}) do
    %{log_record | exception: exception}
  end

  defp put_exception(log_record, _meta), do: log_record

  # Severity mapping per `logs/data-model.md` §Mapping of
  # `SeverityNumber` L273-L296 + Appendix B Syslog row
  # (L806-L818). `:logger` levels are lowercased RFC 5424
  # Syslog levels, so Appendix B is the authoritative
  # source for the numeric values here. Kept private
  # because only this handler consumes it — other bridges
  # define their own mapping from their source format.
  @spec severity_number(level :: :logger.level()) ::
          Otel.API.Logs.severity_number()
  defp severity_number(:emergency), do: 21
  defp severity_number(:alert), do: 19
  defp severity_number(:critical), do: 18
  defp severity_number(:error), do: 17
  defp severity_number(:warning), do: 13
  defp severity_number(:notice), do: 10
  defp severity_number(:info), do: 9
  defp severity_number(:debug), do: 5

  # `SeverityText` per `logs/data-model.md` L240-L241 — the
  # *"original string representation of the severity as it
  # is known at the source"*. For `:logger` the source
  # representation is the level atom; `Atom.to_string/1`
  # preserves it faithfully (`:emergency → "emergency"`,
  # etc.). OTel short names (`"FATAL"`, `"ERROR3"`) are a
  # display concern derivable from `severity_number`, not
  # what `SeverityText` is for.
  #
  # Return type is `Otel.API.Logs.severity_level()` rather
  # than `String.t()` so the signature communicates that
  # this function only yields the 8 valid `:logger`-level
  # strings, not arbitrary text. `severity_level()` is a
  # `String.t()` alias under the hood (see the Logs
  # moduledoc — Elixir typespecs cannot express a literal
  # string union), so Dialyzer inference is unchanged;
  # the tighter name is for readers.
  @spec severity_text(level :: :logger.level()) :: Otel.API.Logs.severity_level()
  defp severity_text(level), do: Atom.to_string(level)
end
