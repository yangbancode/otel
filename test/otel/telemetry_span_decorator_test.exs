defmodule Otel.TelemetrySpanDecoratorTest do
  # async: false — attaches `:telemetry` handlers, which are
  # global per-pid. Compile-fixture modules are also defined
  # at the top of this file (single global namespace).
  use ExUnit.Case, async: false

  # ---- compile-time fixtures ----
  #
  # Each fixture exercises one shape of `@span`. They live at
  # the top of the file so module compilation happens once,
  # before any test runs.

  defmodule SingleClause do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_test, :single]
    def hello(name), do: "hello #{name}"
  end

  defmodule MultiClause do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_test, :multi]
    def kind(0), do: :zero
    def kind(n) when n > 0, do: :positive
    def kind(_), do: :negative
  end

  defmodule DefaultArg do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_test, :default]
    def greet(name, greeting \\ "hello"), do: "#{greeting} #{name}"
  end

  defmodule PatternArg do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_test, :pattern]
    def first_name(%{name: name}), do: name
  end

  defmodule UnderscoreArg do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_test, :underscore]
    def add(a, _ignored, b), do: a + b
  end

  defmodule WithGuard do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_test, :guard]
    def positive?(n) when is_integer(n) and n > 0, do: true
    def positive?(_), do: false
  end

  defmodule PrivateFn do
    use Otel.TelemetrySpanDecorator

    def public_call(x), do: private_helper(x)

    @span [:otel_dec_test, :private]
    defp private_helper(x), do: x * 2
  end

  defmodule NoSpan do
    use Otel.TelemetrySpanDecorator

    def plain(x), do: x + 1
  end

  defmodule RaisingFn do
    use Otel.TelemetrySpanDecorator

    @span [:otel_dec_test, :raises]
    def explode!, do: raise("boom")
  end

  # ---- helpers ----

  defp attach_capture(events) do
    ref = make_ref()
    test_pid = self()

    :telemetry.attach_many(
      {ref, events},
      Enum.flat_map(events, fn prefix ->
        Enum.map([:start, :stop, :exception], &(prefix ++ [&1]))
      end),
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach({ref, events}) end)
    :ok
  end

  describe "single-clause def" do
    test "wraps body in :telemetry.span/3; args flat at top level" do
      attach_capture([[:otel_dec_test, :single]])

      assert SingleClause.hello("world") == "hello world"

      assert_receive {:telemetry, [:otel_dec_test, :single, :start], _measure, start_meta}
      assert start_meta.name == "world"

      assert_receive {:telemetry, [:otel_dec_test, :single, :stop], %{duration: _}, _}
    end
  end

  describe "multi-clause def" do
    test "all clauses share the same wrapping; one span per call" do
      attach_capture([[:otel_dec_test, :multi]])

      assert MultiClause.kind(0) == :zero
      assert MultiClause.kind(5) == :positive
      assert MultiClause.kind(-1) == :negative

      # Three calls → three start events, three stop events.
      for _ <- 1..3 do
        assert_receive {:telemetry, [:otel_dec_test, :multi, :start], _, _}
        assert_receive {:telemetry, [:otel_dec_test, :multi, :stop], _, _}
      end
    end
  end

  describe "default args" do
    test "captures both required and defaulted arg at top level" do
      attach_capture([[:otel_dec_test, :default]])

      assert DefaultArg.greet("world") == "hello world"

      assert_receive {:telemetry, [:otel_dec_test, :default, :start], _, meta}
      assert meta.name == "world"
      assert meta.greeting == "hello"
    end
  end

  describe "pattern-match args" do
    test "falls back to positional `arg_<idx>` name" do
      attach_capture([[:otel_dec_test, :pattern]])

      assert PatternArg.first_name(%{name: "alice"}) == "alice"

      assert_receive {:telemetry, [:otel_dec_test, :pattern, :start], _, meta}
      # Pattern arg → no source name, captured as arg_0
      assert meta.arg_0 == %{name: "alice"}
    end
  end

  describe "underscore args" do
    test "underscore-prefixed args ARE captured (no drop)" do
      attach_capture([[:otel_dec_test, :underscore]])

      assert UnderscoreArg.add(1, :ignored, 2) == 3

      assert_receive {:telemetry, [:otel_dec_test, :underscore, :start], _, meta}
      assert meta.a == 1
      assert meta.b == 2
      # Leading `_` preserved in the metadata key — privacy
      # filtering is the caller's responsibility, not ours.
      assert meta._ignored == :ignored
    end
  end

  describe "return value capture" do
    test "stop event carries :__result__; start carries args (separate)" do
      attach_capture([[:otel_dec_test, :single]])

      assert SingleClause.hello("ada") == "hello ada"

      # `:telemetry.span/3` keeps start and stop metadata
      # separate when the span function returns a 2-tuple —
      # start has args at top level, stop has only
      # `:__result__`. `Otel.TelemetryTracer` calls
      # `set_attributes` on both events, so the OTel span
      # ends up with the union (see the e2e test).
      assert_receive {:telemetry, [:otel_dec_test, :single, :start], _, start_meta}
      assert start_meta.name == "ada"

      assert_receive {:telemetry, [:otel_dec_test, :single, :stop], _, stop_meta}
      assert stop_meta.__result__ == "hello ada"
    end
  end

  describe "guards" do
    test "guards on individual clauses still dispatch correctly" do
      attach_capture([[:otel_dec_test, :guard]])

      assert WithGuard.positive?(5) == true
      assert WithGuard.positive?(-1) == false
      assert WithGuard.positive?("x") == false

      for _ <- 1..3 do
        assert_receive {:telemetry, [:otel_dec_test, :guard, :start], _, _}
        assert_receive {:telemetry, [:otel_dec_test, :guard, :stop], _, _}
      end
    end
  end

  describe "defp" do
    test "private functions can also be decorated" do
      attach_capture([[:otel_dec_test, :private]])

      assert PrivateFn.public_call(3) == 6

      assert_receive {:telemetry, [:otel_dec_test, :private, :start], _, meta}
      assert meta.x == 3
    end
  end

  describe "no @span" do
    test "function without @span passes through unchanged (no telemetry event)" do
      attach_capture([[:otel_dec_test, :unused]])

      assert NoSpan.plain(41) == 42

      refute_receive {:telemetry, _, _, _}, 100
    end
  end

  describe "exception path" do
    test "raised exception → :exception event + reraised" do
      attach_capture([[:otel_dec_test, :raises]])

      assert_raise RuntimeError, "boom", fn -> RaisingFn.explode!() end

      assert_receive {:telemetry, [:otel_dec_test, :raises, :exception], _, meta}
      assert meta.kind == :error
      assert meta.reason == %RuntimeError{message: "boom"}
    end
  end
end
