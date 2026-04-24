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
  | `{:report, map}` | `primitive_any()`-normalised map (keys stringified, values normalised recursively) |
  | `{:report, keyword_list}` | keyword list converted to map, then normalised as above |
  | `{format, args}` (`:io_lib.format/2` shape) | formatted string |
  | anything else | normalised through the same `primitive_any()` pipeline (maps stay maps, primitives stay primitives, others coerced to strings) |

  Values inside a report that don't fit OTel's `AnyValue` —
  atoms, structs, tuples, references, pids, functions — are
  converted to strings. Values that implement the
  `String.Chars` protocol (atoms, `Date`/`DateTime`/`Time`,
  `URI`, `Version`, `Regex`, user structs with
  `defimpl String.Chars`, etc.) use `to_string/1` to honor
  the canonical string form: `~D[2024-01-01]` → `"2024-01-01"`,
  `:ok` → `"ok"`. Values without a `String.Chars` impl
  (tuples, pids, refs, functions, `MapSet`) fall back to
  `inspect/1`. Body therefore stays strictly within
  `primitive_any()` at every depth without flattening
  structs to `%{"__struct__" => Date, ...}`. Primitive
  values (`String.t()`, `integer()`, `float()`, `boolean()`,
  `nil`, and the `{:bytes, binary()}` tag) pass through
  unchanged.

  ### `meta.report_cb` — explicit formatter callback

  When `meta.report_cb` is present on a `{:report, _}`
  message, the callback takes precedence over structural
  preservation — its presence is the caller's (or OTP's
  auto-injection's) explicit declaration of the intended
  rendering, so its return value becomes the Body as a
  string. Matches OTP `:logger` convention and the erlang
  reference (`otel_otlp_logs.erl` L127-L157).

  Two callback arities are supported per OTP `logger.erl`
  L84-L88:

  | Arity | Signature | Handling |
  |---|---|---|
  | `/1` | `(report()) -> {io:format(), [term()]}` | Format tuple is fed to `:io_lib.format/2`, result coerced to `String.t()` |
  | `/2` | `(report(), report_cb_config()) -> unicode:chardata()` | Chardata return is coerced to `String.t()` directly. Config passed is `%{depth: :unlimited, chars_limit: :unlimited, single_line: false}` — OTel backends render their own limits |

  When no `report_cb` is present, the report is preserved
  as a structured map per the table above.

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

  ## Design notes

  Two intentional divergences from `opentelemetry-erlang`'s
  `otel_otlp_logs.erl` reference implementation — both trade
  OTP's terminal-display conventions for OTel data-model
  alignment.

  ### 1. No trim / single-line post-processing on string Bodies

  Erlang (`otel_otlp_logs.erl` L72-L83) trims leading and
  trailing whitespace from formatted string Bodies and
  replaces `\\n`-runs with `, ` to force single-line output.
  We pass chardata through `IO.chardata_to_string/1`
  verbatim — `{:string, _}` messages, `{format, args}`
  messages, and `report_cb` callback results all preserve
  their line breaks. The `report_cb/2` config we emit also
  passes `single_line: false`.

  Multi-line preservation is part of the source
  representation. Single-line collapse is a terminal-display
  concern handled by OTel backends (Jaeger, Tempo, Loki,
  etc.), which render line breaks from the string value
  themselves.

  ### 2. Key stringification at the handler, not the encoder

  Erlang (`otel_otlp_logs.erl` L119) defers map-key
  stringification to `to_any_value/1` at the OTLP encoder
  step, so in-process consumers reading the record before
  OTLP encoding see the original atom-keyed form. We
  normalise keys recursively inside `to_primitive_any/1` so
  `log_record.body` arrives at every processor / exporter
  with string keys at every depth.

  `apps/otel_api/lib/otel/api/logs/log_record.ex` L73 types
  `body: primitive_any()`, whose recursive definition
  requires `%{String.t() => primitive_any()}` at every
  depth. Doing the conversion at the handler honours the
  type contract uniformly across all exporter paths (OTLP,
  custom in-process processors, console debug exporter),
  not just OTLP.
  """

  use Otel.API.Common.Types

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
      timestamp: to_timestamp(meta),
      severity_number: to_severity_number(level),
      severity_text: to_severity_text(level),
      body: to_body(msg, meta),
      attributes: to_attributes(meta)
    }

    put_exception(base, meta)
  end

  # `:time` is guaranteed on `meta` by `:logger`'s
  # `add_default_metadata/1` (OTP `logger.erl` L1193-L1214),
  # which runs on every `:logger.log/2`, `Logger.info/1`,
  # `:logger:info/N` call path. The `:time` pattern match
  # asserts that invariant — meta without `:time` raises
  # `FunctionClauseError`, which is `:logger`'s own contract
  # for removing malformed handlers (self-healing).
  #
  # µs → ns scaling per OTP's `microsecond` default
  # (`logger.erl` L365-L366) and OTel `Timestamp` which is
  # nanoseconds-since-epoch (`logs/data-model.md` L184-L187).
  @spec to_timestamp(meta :: map()) :: non_neg_integer()
  defp to_timestamp(%{time: time}), do: time * 1000

  # Body extraction — `logs/data-model.md` L399-L400 requires
  # preserving `AnyValue` structure for structured logs. When
  # `meta.report_cb` is set (user-provided formatter, or OTP
  # auto-injected for crash reports), it takes precedence: the
  # callback's return is the explicit rendering the caller
  # declared, so we honour it over structural preservation.
  # Without `report_cb`, `{:report, _}` flows through
  # `to_primitive_any/1` and arrives as a normalised map.
  @spec to_body(msg :: term(), meta :: map()) :: primitive_any()

  # `report_cb/1` (OTP `logger.erl` L84): returns `{format, args}`.
  # Format via `:io_lib.format/2` — output is already `String.t()`,
  # which is in `primitive_any()`, so no `to_primitive_any/1` needed.
  defp to_body({:report, report}, %{report_cb: cb}) when is_function(cb, 1) do
    {format, args} = cb.(report)
    :io_lib.format(format, args) |> IO.chardata_to_string()
  end

  # `report_cb/2` (OTP `logger.erl` L85): returns `unicode:chardata()`
  # directly, taking a config with `depth` / `chars_limit` /
  # `single_line`. We pass `:unlimited` / `false` — OTP's defaults
  # optimise for terminal display; OTel backends render their own
  # limits (see `## Design notes`).
  defp to_body({:report, report}, %{report_cb: cb}) when is_function(cb, 2) do
    config = %{depth: :unlimited, chars_limit: :unlimited, single_line: false}
    cb.(report, config) |> IO.chardata_to_string()
  end

  defp to_body({:string, string}, _meta) do
    IO.chardata_to_string(string)
  end

  defp to_body({:report, report}, _meta) when is_map(report) do
    to_primitive_any(report)
  end

  defp to_body({:report, report}, _meta) when is_list(report) do
    report |> Enum.into(%{}) |> to_primitive_any()
  end

  defp to_body({format, args}, _meta) when is_list(format) do
    :io_lib.format(format, args) |> IO.chardata_to_string()
  end

  # Defensive clause — OTP `:logger` normalises every message
  # into one of the three shapes above (`logger.erl` L1159-L1177),
  # so this only fires when a caller (typically a test) invokes
  # `log/2` directly with a hand-rolled event. `to_primitive_any/1`
  # handles raw terms consistently with the `:report` paths above
  # — an untagged map like `%{user_id: 42}` is preserved as a
  # normalised map rather than stringified.
  defp to_body(other, _meta) do
    to_primitive_any(other)
  end

  # Normalise any Elixir term to `primitive_any()` — OTel's
  # `AnyValue` (`common/README.md` §AnyValue L39-L54), mirrored
  # in our project-local `primitive_any()` type
  # (`apps/otel_api/lib/otel/api/common/types.ex` L183-L184):
  #
  #     primitive_any() ::
  #       primitive() | [primitive_any()] | %{String.t() => primitive_any()}
  #
  # `primitive()` = `String.t() | {:bytes, binary()} | boolean()
  # | integer() | float() | nil`. Anything outside that union
  # (arbitrary atoms like `:ok`, structs like `%Date{}`, tuples
  # other than the `:bytes` tag, references, pids, functions)
  # has no `AnyValue` representation, so we render it via
  # `inspect/1` — matches Elixir's own `Logger` default
  # formatter and preserves a human-readable form without
  # leaking `__struct__`-style internals.
  #
  # Maps recurse with `to_string(k)` on keys so the
  # `map<string, AnyValue>` contract holds at every depth.
  # Lists recurse element-wise so nested composites are
  # normalised too. Struct-valued fields hit the catch-all
  # `inspect/1` clause rather than being flattened to
  # `%{"__struct__" => Date, ...}`.
  @spec to_primitive_any(value :: term()) :: primitive_any()
  defp to_primitive_any(nil), do: nil
  defp to_primitive_any(value) when is_boolean(value), do: value
  defp to_primitive_any(value) when is_binary(value), do: value
  defp to_primitive_any(value) when is_integer(value), do: value
  defp to_primitive_any(value) when is_float(value), do: value
  defp to_primitive_any({:bytes, bin} = value) when is_binary(bin), do: value

  defp to_primitive_any(value) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} -> {to_string(k), to_primitive_any(v)} end)
  end

  defp to_primitive_any(value) when is_list(value) do
    Enum.map(value, &to_primitive_any/1)
  end

  # Non-primitive, non-composite catch-all: atoms, structs,
  # tuples, references, pids, functions. Prefer `to_string/1`
  # when the value implements `String.Chars` — that protocol
  # IS the user/library declaration of "this is the canonical
  # string form" (e.g. `Date` renders as `"2024-01-01"`, `URI`
  # as `"http://..."`, `:ok` as `"ok"`). Values without a
  # `String.Chars` impl (tuples, pids, refs, ports, functions,
  # `MapSet`, etc.) fall back to `inspect/1`. `String.Chars.
  # impl_for/1` returns the impl module or `nil`, so this is a
  # pure dispatch — no `try/rescue`.
  defp to_primitive_any(value) do
    case String.Chars.impl_for(value) do
      nil -> inspect(value)
      _impl -> to_string(value)
    end
  end

  @spec to_attributes(meta :: map()) :: map()
  defp to_attributes(meta) do
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
  @spec to_severity_number(level :: :logger.level()) ::
          Otel.API.Logs.severity_number()
  defp to_severity_number(:emergency), do: 21
  defp to_severity_number(:alert), do: 19
  defp to_severity_number(:critical), do: 18
  defp to_severity_number(:error), do: 17
  defp to_severity_number(:warning), do: 13
  defp to_severity_number(:notice), do: 10
  defp to_severity_number(:info), do: 9
  defp to_severity_number(:debug), do: 5

  # `SeverityText` per `logs/data-model.md` L240-L241 — the
  # *"original string representation of the severity as it
  # is known at the source"*. For `:logger` the source
  # representation is the level atom; `Atom.to_string/1`
  # preserves it faithfully (`:emergency → "emergency"`,
  # etc.). OTel short names (`"FATAL"`, `"ERROR3"`) are a
  # display concern derivable from `severity_number` per
  # §Displaying Severity L334-L363, not what `SeverityText`
  # is for.
  #
  # Return type is `Otel.API.Logs.severity_level()` rather
  # than `String.t()` to document that the output is one of
  # the 8 valid `:logger`-level strings, not arbitrary text.
  # `severity_level()` is a `String.t()` alias under the
  # hood (Elixir typespecs cannot express a literal string
  # union), so Dialyzer inference is unchanged — the tighter
  # name is for readers.
  @spec to_severity_text(level :: :logger.level()) :: Otel.API.Logs.severity_level()
  defp to_severity_text(level), do: Atom.to_string(level)
end
