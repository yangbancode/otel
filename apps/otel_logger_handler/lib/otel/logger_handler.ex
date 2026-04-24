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

  These three shapes are the full `:logger.msg/0` contract
  (OTP `logger.erl` L76-L80) — any other shape is a caller
  contract violation and raises `FunctionClauseError`,
  handled by `:logger`'s internal `try/catch` via
  self-healing handler removal.

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
  `meta.crash_reason = {exception, stacktrace}`. The two
  halves of the tuple land in two OTel-aligned destinations:

  - **`exception` struct** → `log_record.exception` field
    (`Otel.API.Logs.LogRecord.t/0`). API-layer MAY-accepted
    sidecar per `api.md` L131. SDK converts this to the
    stable `exception.type` and `exception.message`
    attributes (reading `.__struct__` and calling
    `Exception.message/1`).
  - **`stacktrace`** → `log_record.attributes` under
    `"exception.stacktrace"` (stable semconv attribute per
    `semantic-conventions/model/exceptions/registry.yaml`
    L27-L38). Handler emits it directly because Elixir
    exception structs don't carry stacktrace (it's a
    separate value in the language's exception model), so
    the SDK's struct-based extraction can't reach it. The
    handler formats via `Exception.format_stacktrace/1` —
    the idiomatic BEAM representation that matches spec's
    *"natural representation for the language runtime"*.

  Non-exception `:crash_reason` shapes (`{:exit, reason}`,
  `{:shutdown, term}`, etc.) are ignored — neither sidecar
  nor attribute is populated, since they don't fit the
  `Exception.t()` type or the `exception.*` attribute
  semantics.

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
  | `domain: [atom]` | `log.domain` | non-standard convenience; emitted as `[String.t()]` so backends can filter by path segment |
  | `crash_reason: {exc, stack}` (exception shape) | `exception.stacktrace` | formatted via `Exception.format_stacktrace/1`; non-exception `crash_reason` shapes (`{:exit, _}`, `{:shutdown, _}`) produce no attribute. See `## Exception events` |

  `pid` is intentionally **not** emitted — `process.pid` is
  an int-typed OS PID attribute in semantic-conventions and
  does not fit an Erlang PID (`#PID<0.123.0>`). A follow-up
  decision will settle whether to emit it under a
  BEAM-specific custom key or drop it entirely.

  ### Format choices

  `code.function.name` renders as
  `"\#{inspect(module)}.\#{function}/\#{arity}"` — two
  choices worth surfacing:

  1. **Arity is included.** The spec's Elixir example at
     `semantic-conventions/model/code/registry.yaml` L31 is
     `OpenTelemetry.Ctx.new` (arity-less), but L20 notes
     *"Values and format depends on each language runtime"*.
     BEAM conventions (stacktrace format, OTP's `mfa` tuple,
     `Exception.format_mfa/3`) include arity, and `handle/2`
     vs `handle/3` are genuinely distinct functions — omitting
     arity would lose information.

  2. **`inspect(module)` strips the `Elixir.` prefix.** Module
     atoms are stored internally as `:"Elixir.<Name>"`;
     `inspect/1` drops the prefix (`inspect(MyApp.Worker)` →
     `"MyApp.Worker"`), while `Atom.to_string/1` / `to_string/1`
     keep it (`"Elixir.MyApp.Worker"`). For `code.function.name`
     the user-readable form matters to backends and stacktraces.
     This intentionally differs from `to_primitive_any/1`
     (body-value path), which uses `to_string/1` and accepts
     the prefix — each function's use case dictates the choice.

  `log.domain` is `[String.t()]` (homogeneous array) so
  backends can filter by individual path segments
  (`log.domain[0] = "elixir"`). A stringified literal like
  `"[:elixir, :phoenix]"` wouldn't support segment queries.

  ### User metadata pass-through

  `:logger` accepts arbitrary user-provided metadata via
  `Logger.metadata/1` or per-call meta args. Every key not
  in the reserved list below flows through as a custom
  attribute — the key is `Atom.to_string(meta_key)` and the
  value is coerced to `primitive() | [primitive()]`:

      Logger.metadata(request_id: "req-abc", user_id: 42)
      Logger.info("processed")
      # attributes: %{"request_id" => "req-abc", "user_id" => 42, ...}

  Reserved keys (not emitted as custom attributes, for three
  distinct reasons):

  | Key | Reason |
  |---|---|
  | `:mfa`, `:file`, `:line`, `:domain` | Already mapped above to semconv-stable `code.*` / `log.domain` names |
  | `:time` | Consumed by `to_timestamp/1` → `timestamp` field |
  | `:report_cb` | Consumed by `to_body/2` → body render |
  | `:crash_reason` | Consumed by `to_exception/1` → `exception` field, and by `put_exception_stacktrace/2` → `exception.stacktrace` attribute |
  | `:gl` | Group-leader PID — process-internal, no OTel semantic |
  | `:pid` | `process.pid` type mismatch (see above) |

  Value coercion is **flat** (unlike `to_primitive_any/1`
  which recurses through nested maps for body) —
  `common/README.md` §Attribute L185-L197 forbids map-valued
  attributes. Primitives (`String.t()`, `integer()`,
  `float()`, `boolean()`, `nil`, `{:bytes, binary()}`) pass
  through. Non-primitives (atoms, structs, tuples, PIDs,
  refs, functions) coerce to string via `String.Chars` when
  implemented, `inspect/1` otherwise. Lists become
  homogeneous primitive arrays via element-wise coercion.
  Nested maps — which have no valid attribute
  representation — fall through to `inspect/1`.

  ### Divergence from `opentelemetry-erlang`

  Erlang's attribute extraction happens in the OTLP exporter
  (`otel_otlp_logs.erl` L84) as `maps:without([gl, time,
  report_cb], Metadata)` — a blacklist with raw atom keys
  (`mfa`, `file`, `line`, `domain`) that are **not**
  semconv-stable names. We instead:

  1. Map `:mfa` / `:file` / `:line` / `:domain` to their
     stable semconv names (`code.function.name`, etc.).
  2. Run extraction at the handler so every exporter (OTLP,
     custom, in-process debug) sees the canonical attribute
     shape without re-work.
  3. Blacklist a broader set (`:gl`, `:time`, `:report_cb`,
     `:crash_reason`, `:pid`) reflecting OTel semantic
     concerns rather than just display.

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
    %Otel.API.Logs.LogRecord{
      timestamp: to_timestamp(meta),
      severity_number: to_severity_number(level),
      severity_text: to_severity_text(level),
      body: to_body(msg, meta),
      attributes: to_attributes(meta),
      exception: to_exception(meta)
    }
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

  # Normalise any Elixir term to `primitive_any()` — OTel's
  # `AnyValue` (`common/README.md` §AnyValue L39-L54), mirrored
  # in our project-local `primitive_any()` type
  # (`apps/otel_api/lib/otel/api/common/types.ex` L183-L184):
  #
  #     primitive_any() ::
  #       primitive() | [primitive_any()] | %{String.t() => primitive_any()}
  #
  # Composite handling (maps, lists) lives here; scalar
  # coercion is delegated to `to_primitive/1` so the body and
  # attribute paths share a single leaf-coercion policy.
  #
  # Maps recurse with `to_string(k)` on keys so the
  # `map<string, AnyValue>` contract holds at every depth.
  # Lists recurse element-wise so nested composites are
  # normalised too. Everything else (primitives, atoms,
  # structs, tuples outside `:bytes`, refs, pids, functions)
  # delegates to `to_primitive/1`.
  @spec to_primitive_any(value :: term()) :: primitive_any()
  defp to_primitive_any(value) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} -> {to_string(k), to_primitive_any(v)} end)
  end

  defp to_primitive_any(value) when is_list(value) do
    Enum.map(value, &to_primitive_any/1)
  end

  defp to_primitive_any(value), do: to_primitive(value)

  # Leaf coercion — any non-composite Elixir term to
  # `primitive()` (`common/types.ex` L180-L181: `String.t() |
  # {:bytes, binary()} | boolean() | integer() | float() |
  # nil`). Shared between `to_primitive_any/1` (body path)
  # and `to_attribute_value/1` (attribute path).
  #
  # Primitives pass through unchanged. Anything outside
  # `primitive()` — atoms, structs, tuples other than the
  # `:bytes` tag, references, pids, functions — has no
  # `AnyValue` representation, so we coerce to `String.t()`:
  # `String.Chars` impl (canonical form per the
  # user/library) when present, `inspect/1` otherwise. The
  # `String.Chars.impl_for/1` dispatch returns the impl
  # module or `nil`, so this is pure dispatch — no
  # `try/rescue`.
  #
  # Callsites:
  #
  # - `to_primitive_any/1` — body path; delegates here for
  #   every non-map, non-list value.
  # - `to_attribute_value/1` — attribute path; delegates
  #   here for every non-list value, and via `Enum.map` for
  #   list elements.
  @spec to_primitive(value :: term()) :: primitive()
  defp to_primitive(nil), do: nil
  defp to_primitive(value) when is_boolean(value), do: value
  defp to_primitive(value) when is_binary(value), do: value
  defp to_primitive(value) when is_integer(value), do: value
  defp to_primitive(value) when is_float(value), do: value
  defp to_primitive({:bytes, bin} = value) when is_binary(bin), do: value

  defp to_primitive(value) do
    case String.Chars.impl_for(value) do
      nil -> inspect(value)
      _impl -> to_string(value)
    end
  end

  # `:logger` meta keys NOT emitted as custom attributes by
  # `put_user_meta/2` — either handled by a specialised
  # `put_*` helper below (which maps them to a stable semconv
  # attribute name), consumed elsewhere in the
  # `build_log_record/1` pipeline, or dropped for
  # spec-conformance reasons.
  @reserved_meta_keys [
    # Mapped by specialised put_* helpers below
    :mfa,
    :file,
    :line,
    :domain,
    :crash_reason,
    # Consumed elsewhere in the build_log_record pipeline
    :time,
    :report_cb,
    # Dropped for spec-conformance
    :gl,
    :pid
  ]

  @spec to_attributes(meta :: map()) :: map()
  defp to_attributes(meta) do
    %{}
    |> put_code_function_name(meta)
    |> put_code_file_path(meta)
    |> put_code_line_number(meta)
    |> put_log_domain(meta)
    |> put_exception_stacktrace(meta)
    |> put_user_meta(meta)
  end

  @spec put_code_function_name(attrs :: map(), meta :: map()) :: map()
  defp put_code_function_name(attrs, %{mfa: {module, function, arity}}) do
    Map.put(attrs, "code.function.name", "#{inspect(module)}.#{function}/#{arity}")
  end

  defp put_code_function_name(attrs, _meta), do: attrs

  @spec put_code_file_path(attrs :: map(), meta :: map()) :: map()
  defp put_code_file_path(attrs, %{file: file}) do
    Map.put(attrs, "code.file.path", IO.chardata_to_string(file))
  end

  defp put_code_file_path(attrs, _meta), do: attrs

  @spec put_code_line_number(attrs :: map(), meta :: map()) :: map()
  defp put_code_line_number(attrs, %{line: line}) do
    Map.put(attrs, "code.line.number", line)
  end

  defp put_code_line_number(attrs, _meta), do: attrs

  @spec put_log_domain(attrs :: map(), meta :: map()) :: map()
  defp put_log_domain(attrs, %{domain: domain}) do
    Map.put(attrs, "log.domain", Enum.map(domain, &Atom.to_string/1))
  end

  defp put_log_domain(attrs, _meta), do: attrs

  # Only the `{exception, stacktrace}` shape of `:crash_reason`
  # yields a valid `exception.stacktrace` attribute. OTP can
  # also set `:crash_reason` to `{:exit, term}` or
  # `{:shutdown, term}` for non-exception exits — the fallback
  # clause ensures those produce no attribute rather than a
  # misleading one.
  @spec put_exception_stacktrace(attrs :: map(), meta :: map()) :: map()
  defp put_exception_stacktrace(attrs, %{crash_reason: {exception, stacktrace}})
       when is_exception(exception) do
    Map.put(attrs, "exception.stacktrace", Exception.format_stacktrace(stacktrace))
  end

  defp put_exception_stacktrace(attrs, _meta), do: attrs

  # Forwards user-provided `:logger` meta entries
  # (`Logger.metadata/1` or per-call `meta` arg) as custom
  # attributes. Keys in `@reserved_meta_keys` are excluded —
  # either handled by the specialised `put_*` helpers above
  # or dropped by design (see moduledoc `## Attribute mapping`).
  #
  # Attribute key is `Atom.to_string(meta_key)`. Attribute
  # value is normalised via `to_attribute_value/1`. `nil`
  # user-meta values are preserved — user's explicit choice,
  # not conflated with "key absent". Specialised helpers
  # above use pattern matching with a fallback clause for
  # absent/malformed values, which is appropriate for
  # semconv-mapped keys where "missing" and "nil-valued"
  # aren't practically distinguishable.
  @spec put_user_meta(attrs :: map(), meta :: map()) :: map()
  defp put_user_meta(attrs, meta) do
    meta
    |> Map.drop(@reserved_meta_keys)
    |> Enum.reduce(attrs, fn {key, value}, acc ->
      Map.put(acc, Atom.to_string(key), to_attribute_value(value))
    end)
  end

  # Coerces any Elixir term to `primitive() | [primitive()]`
  # — the attribute-value type from `LogRecord.t/0`
  # (`apps/otel_api/lib/otel/api/logs/log_record.ex` L74).
  #
  # Similar to `to_primitive_any/1` (body path) but FLATTER:
  # OTel attributes don't permit nested maps
  # (`common/README.md` §Attribute L185-L197 — values must be
  # primitive or homogeneous primitive arrays). A list
  # iterates to a homogeneous primitive array via
  # `to_primitive/1` on each element; non-list values go
  # through `to_primitive/1` directly.
  @spec to_attribute_value(value :: term()) :: primitive() | [primitive()]
  defp to_attribute_value(value) when is_list(value), do: Enum.map(value, &to_primitive/1)
  defp to_attribute_value(value), do: to_primitive(value)

  # Exception struct from `meta.crash_reason = {exception,
  # stacktrace}` — OTP's standard crash-report shape. Returns
  # the exception (Exception.t()) for the `log_record.exception`
  # sidecar field; SDK converts that to `exception.type` and
  # `exception.message` attributes per `trace/exceptions.md`
  # §Attributes L44-L55. Stacktrace is handled separately by
  # `put_exception_stacktrace/2` (it doesn't fit the
  # `log_record.exception` sidecar because Elixir exception
  # structs don't carry stacktrace; see `## Exception events`).
  #
  # Non-exception `crash_reason` shapes (`{:exit, _}`,
  # `{:shutdown, _}`) return `nil` via the fallback clause —
  # `log_record.exception` defaults to `nil` so no-op vs
  # explicit-nil is equivalent.
  @spec to_exception(meta :: map()) :: Exception.t() | nil
  defp to_exception(%{crash_reason: {exception, _stack}}) when is_exception(exception) do
    exception
  end

  defp to_exception(_meta), do: nil

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
