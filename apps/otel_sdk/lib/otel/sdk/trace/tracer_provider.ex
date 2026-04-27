defmodule Otel.SDK.Trace.TracerProvider do
  @moduledoc """
  SDK implementation of the `Otel.API.Trace.TracerProvider`
  behaviour (`trace/sdk.md` §TracerProvider L36-L116).

  A `GenServer` that owns trace configuration (sampler,
  processors, id_generator, resource, span_limits) and creates
  tracers. Registers itself as the global TracerProvider on
  start.

  ## Provider-owned processor lifecycle

  When a registered processor module exports `start_link/1`,
  the TracerProvider starts it as a linked child during
  `init/1`, captures the resulting PID, and passes that PID
  to every behaviour callback (`on_start/3`, `on_end/2`,
  `shutdown/2`, `force_flush/2`) via the `%{pid: pid}` config.
  The user does not start processors separately and does not
  provide an atom registration name — the TracerProvider owns
  the lifecycle.

  This mirrors the typical OTel SDK pattern (Java, Go, Python,
  and erlang's `otel_tracer_server.erl:158-183` —
  `init_processor` starting children under a dedicated
  supervisor).

  Modules without a `start_link/1` export are registered as
  *module-only* processors (no process, no PID). Their callback
  config is whatever the user supplied verbatim. This supports
  pure-callback fixtures used in tests; production processors
  (`Simple`, `Batch`) all expose `start_link/1`.

  ## Crash handling

  `init/1` enables `trap_exit` so a processor crash is
  delivered to the TracerProvider as `{:EXIT, pid, reason}`
  rather than propagating along the link. The dead processor
  is removed from both the in-memory list and the
  `:persistent_term` fast path that `Tracer.start_span` and
  `Span.end_span` walk — graceful degradation, the other
  processors keep working. Once removed, the processor is
  **not** re-added; if its module is supervised by us, the
  TracerProvider's own crash takes its linked processors with
  it (no orphans).

  All public functions are safe for concurrent use, satisfying
  spec `trace/api.md` L843-L853 (Status: Stable, #4887) —
  *"TracerProvider — all methods MUST be documented that
  implementations need to be safe for concurrent use by
  default."*

  ## Public API

  | Function | Role |
  |---|---|
  | `start_link/1` | **SDK** (lifecycle) |
  | `get_tracer/2` | **SDK** (OTel API MUST) — `trace/api.md` §Get a Tracer L107-L157 |
  | `shutdown/2` | **SDK** (OTel API MUST) — `trace/sdk.md` §Shutdown |
  | `force_flush/2` | **SDK** (OTel API MUST) — `trace/sdk.md` §ForceFlush |

  ## Deferred Development-status features

  - **TracerConfig (`enabled` flag).** Spec
    `trace/sdk.md` L197-L218 (Status: Development) defines a
    per-Tracer config with `enabled: true | false`. When
    `enabled=false`, the Tracer MUST behave equivalently to a
    No-op Tracer. Not implemented — every Tracer obtained from
    this provider is currently always active. The
    no-SpanProcessors leg of `Tracer.enabled?/2` (spec L223-L227)
    IS honoured (see `tracer.ex`); the disabled-Tracer leg waits
    for spec stabilisation.

  ## References

  - OTel Trace SDK §TracerProvider: `opentelemetry-specification/specification/trace/sdk.md` L36-L116
  - OTel Trace API §TracerProvider: `opentelemetry-specification/specification/trace/api.md` L88-L157
  """

  require Logger

  use GenServer
  @behaviour Otel.API.Trace.TracerProvider

  @typedoc """
  A registered processor in the provider state.

  - `:module` — the `SpanProcessor` implementation.
  - `:pid` — the PID returned by `module.start_link/1`, or
    `nil` for module-only processors that expose no
    `start_link/1`.
  - `:callback_config` — what the TracerProvider passes to
    every behaviour callback. `%{pid: pid}` for process-backed
    processors, the user's original config map for module-only
    processors.
  """
  @type processor_entry :: %{
          module: module(),
          pid: pid() | nil,
          callback_config: Otel.SDK.Trace.SpanProcessor.config()
        }

  @typedoc """
  Runtime state held by the TracerProvider GenServer.

  - `:sampler` / `:processors` / `:id_generator` / `:resource`
    / `:span_limits` come from the user's `start_link/1` config
    (or defaults).
  - `:shut_down` is the lifecycle flag flipped by
    `handle_call({:shutdown, _}, _, _)`. Once `true`,
    `get_tracer/2` returns the noop tracer and
    `force_flush/2` / `shutdown/2` reply with
    `{:error, :already_shutdown}`.
  - `:processors_key` is the `:persistent_term` key under
    which `Otel.SDK.Trace.Tracer` reads the projected
    `[{module, callback_config}]` list on every `start_span`
    and `end_span`.
  """
  @type config :: %{
          sampler: {module(), term()},
          processors: [processor_entry()],
          id_generator: module(),
          resource: Otel.SDK.Resource.t(),
          span_limits: Otel.SDK.Trace.SpanLimits.t(),
          shut_down: boolean(),
          processors_key: {module(), :processors, reference()}
        }

  # Default timeout for `shutdown/2` and `force_flush/2`
  # (30000ms). Matches BatchSpanProcessor's `exportTimeoutMillis`
  # default — a reasonable upper bound for the slowest
  # processor cleanup path. The same value is forwarded to each
  # processor's own `shutdown/2` / `force_flush/2` so a
  # single-processor provider has its outer GenServer.call and
  # inner processor budgets aligned.
  @default_shutdown_timeout_ms 30_000
  @default_force_flush_timeout_ms 30_000

  # --- Client API ---

  @doc """
  **SDK** (lifecycle) — Starts the TracerProvider with the
  given configuration.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {config, server_opts} = Keyword.pop(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, server_opts)
  end

  @doc """
  **SDK** (OTel API MUST) — Get a Tracer
  (`trace/api.md` §Get a Tracer L107-L157).

  Falls back to the Noop tracer if `server` is no longer alive.
  """
  @spec get_tracer(
          server :: GenServer.server(),
          instrumentation_scope :: Otel.API.InstrumentationScope.t()
        ) ::
          Otel.API.Trace.Tracer.t()
  @impl Otel.API.Trace.TracerProvider
  def get_tracer(server, %Otel.API.InstrumentationScope{} = instrumentation_scope) do
    if GenServer.whereis(server) do
      GenServer.call(server, {:get_tracer, instrumentation_scope})
    else
      {Otel.API.Trace.Tracer.Noop, []}
    end
  end

  @doc """
  **SDK** (OTel API MUST) — Shutdown
  (`trace/sdk.md` §Shutdown).

  Invokes shutdown on all registered processors. After shutdown,
  `get_tracer/2` returns the noop tracer. Can only be called
  once; subsequent calls reply `{:error, :already_shutdown}`.

  `timeout` is forwarded to each processor's `shutdown/2` and
  also bounds the outer GenServer call. Default 30_000ms.
  """
  @spec shutdown(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(server, timeout \\ @default_shutdown_timeout_ms) do
    GenServer.call(server, {:shutdown, timeout}, timeout)
  end

  @doc """
  **SDK** (OTel API MUST) — ForceFlush
  (`trace/sdk.md` §ForceFlush).

  Forces all registered processors to export pending spans.

  `timeout` is forwarded to each processor's `force_flush/2`
  and also bounds the outer GenServer call. Default 30_000ms.
  """
  @spec force_flush(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(server, timeout \\ @default_force_flush_timeout_ms) do
    GenServer.call(server, {:force_flush, timeout}, timeout)
  end

  @doc """
  **SDK** (introspection) — Returns the resource associated with
  this provider.
  """
  @spec resource(server :: GenServer.server()) :: Otel.SDK.Resource.t()
  def resource(server) do
    GenServer.call(server, :resource)
  end

  @doc """
  **SDK** (introspection) — Returns the current configuration
  snapshot.
  """
  @spec config(server :: GenServer.server()) :: config()
  def config(server) do
    GenServer.call(server, :config)
  end

  # --- Server Callbacks ---

  @impl true
  def init(user_config) do
    Process.flag(:trap_exit, true)

    processors_key = {__MODULE__, :processors, make_ref()}

    base = Map.merge(default_config(), user_config)

    started = Enum.map(Map.get(base, :processors, []), &start_processor/1)

    config =
      base
      |> Map.put(:processors, started)
      |> Map.put(:shut_down, false)
      |> Map.put(:processors_key, processors_key)

    :persistent_term.put(processors_key, project_processors(started))

    Otel.API.Trace.TracerProvider.set_provider({__MODULE__, self_ref()})
    {:ok, config}
  end

  @spec self_ref() :: atom() | pid()
  defp self_ref do
    case Process.info(self(), :registered_name) do
      {:registered_name, name} when is_atom(name) -> name
      _ -> self()
    end
  end

  @impl true
  def handle_call({:get_tracer, _instrumentation_scope}, _from, %{shut_down: true} = config) do
    {:reply, {Otel.API.Trace.Tracer.Noop, []}, config}
  end

  def handle_call(
        {:get_tracer, %Otel.API.InstrumentationScope{} = instrumentation_scope},
        _from,
        config
      ) do
    warn_on_invalid_scope_name(instrumentation_scope)

    sampler = Otel.SDK.Trace.Sampler.new(config.sampler)

    tracer_config = %{
      sampler: sampler,
      id_generator: config.id_generator,
      span_limits: config.span_limits,
      processors_key: config.processors_key,
      resource: config.resource,
      scope: instrumentation_scope
    }

    {:reply, {Otel.SDK.Trace.Tracer, tracer_config}, config}
  end

  def handle_call({:shutdown, _timeout}, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shutdown}, config}
  end

  def handle_call({:shutdown, timeout}, _from, config) do
    result = invoke_all_processors(config.processors, :shutdown, timeout)
    {:reply, result, %{config | shut_down: true}}
  end

  def handle_call({:force_flush, _timeout}, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shutdown}, config}
  end

  def handle_call({:force_flush, timeout}, _from, config) do
    result = invoke_all_processors(config.processors, :force_flush, timeout)
    {:reply, result, config}
  end

  def handle_call(:resource, _from, config) do
    {:reply, config.resource, config}
  end

  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, %{shut_down: true} = config) do
    # Already shutting down — ignore late EXIT signals from
    # processors we just terminated.
    {:noreply, config}
  end

  def handle_info({:EXIT, pid, reason}, config) do
    case Enum.find(config.processors, &(&1.pid == pid)) do
      nil ->
        # EXIT from a process we don't manage; ignore.
        {:noreply, config}

      %{module: module} ->
        Logger.warning(
          "Otel.SDK.Trace.TracerProvider: SpanProcessor #{inspect(module)} (#{inspect(pid)}) exited with #{inspect(reason)}; removing from active list."
        )

        new_processors = Enum.reject(config.processors, &(&1.pid == pid))

        # Update the persistent_term fast path so
        # `Tracer.start_span` / `Span.end_span` stop dispatching
        # to the dead processor immediately.
        :persistent_term.put(config.processors_key, project_processors(new_processors))

        {:noreply, %{config | processors: new_processors}}
    end
  end

  # --- Private ---

  # Spec `trace/api.md` L107-L119 / `trace/sdk.md` parallel —
  # *"In the case where an invalid `name` (null or empty
  # string) is specified, a working `Tracer` MUST be returned
  # as a fallback rather than returning null or throwing an
  # exception, its `name` SHOULD keep the original invalid
  # value, and a message reporting that the specified value is
  # invalid SHOULD be logged."* The MUST is satisfied
  # structurally — we always return the SDK Tracer; the SHOULD
  # log is enforced here.
  @spec warn_on_invalid_scope_name(scope :: Otel.API.InstrumentationScope.t()) :: :ok
  defp warn_on_invalid_scope_name(%Otel.API.InstrumentationScope{name: ""}) do
    Logger.warning(
      "Otel.SDK.Trace.TracerProvider: invalid Tracer name (empty string) — returning a working Tracer as fallback"
    )

    :ok
  end

  defp warn_on_invalid_scope_name(_scope), do: :ok

  @spec default_config() :: %{atom() => term()}
  defp default_config do
    %{
      sampler:
        {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}},
      processors: [],
      id_generator: Otel.SDK.Trace.IdGenerator.Default,
      resource: Otel.SDK.Resource.default(),
      span_limits: %Otel.SDK.Trace.SpanLimits{}
    }
  end

  @spec start_processor({module(), term()}) :: processor_entry()
  defp start_processor({module, init_config}) do
    if function_exported?(module, :start_link, 1) do
      {:ok, pid} = module.start_link(init_config)
      %{module: module, pid: pid, callback_config: %{pid: pid}}
    else
      # Module-only processor — no process to manage, callback
      # config is the user's verbatim init_config.
      %{module: module, pid: nil, callback_config: init_config}
    end
  end

  @spec project_processors([processor_entry()]) ::
          [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
  defp project_processors(processors) do
    Enum.map(processors, fn %{module: m, callback_config: c} -> {m, c} end)
  end

  @spec invoke_all_processors(
          processors :: [processor_entry()],
          function :: :shutdown | :force_flush,
          timeout :: timeout()
        ) :: :ok | {:error, [{module(), term()}]}
  defp invoke_all_processors(processors, function, timeout) do
    results =
      Enum.reduce(processors, [], fn %{module: module, callback_config: callback_config},
                                     errors ->
        case apply(module, function, [callback_config, timeout]) do
          :ok -> errors
          {:error, reason} -> [{module, reason} | errors]
        end
      end)

    case results do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
end
