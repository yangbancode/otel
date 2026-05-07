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

  defmodule Default do
    use Otel.TelemetrySpanDecorator

    # Plain list form — no `capture_io`, only `code.*` injected.
    @span [:otel_dec_test, :default]
    def hello(name), do: "hello #{name}"
  end

  defmodule Captured do
    use Otel.TelemetrySpanDecorator

    # Keyword form with `capture_io: true` — `__args__` and
    # `__result__` included.
    @span event: [:otel_dec_test, :captured], capture_io: true
    def hello(name), do: "hello #{name}"
  end

  defmodule MultiClause do
    use Otel.TelemetrySpanDecorator

    @span event: [:otel_dec_test, :multi], capture_io: true
    def kind(0), do: :zero
    def kind(n) when n > 0, do: :positive
    def kind(_), do: :negative
  end

  defmodule DefaultArg do
    use Otel.TelemetrySpanDecorator

    @span event: [:otel_dec_test, :default_arg], capture_io: true
    def greet(name, greeting \\ "hello"), do: "#{greeting} #{name}"
  end

  defmodule PatternArg do
    use Otel.TelemetrySpanDecorator

    @span event: [:otel_dec_test, :pattern], capture_io: true
    def first_name(%{name: name}), do: name
  end

  defmodule UnderscoreArg do
    use Otel.TelemetrySpanDecorator

    @span event: [:otel_dec_test, :underscore], capture_io: true
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

    @span event: [:otel_dec_test, :private], capture_io: true
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

  describe "default mode (no capture_io)" do
    test "injects code.* attrs only; no __args__ / __result__" do
      attach_capture([[:otel_dec_test, :default]])

      assert Default.hello("world") == "hello world"

      assert_receive {:telemetry, [:otel_dec_test, :default, :start], _, start_meta}
      assert start_meta[:"code.function.name"] == "Otel.TelemetrySpanDecoratorTest.Default.hello"
      assert is_binary(start_meta[:"code.file.path"])
      assert String.ends_with?(start_meta[:"code.file.path"], "telemetry_span_decorator_test.exs")
      assert is_integer(start_meta[:"code.line.number"])
      refute Map.has_key?(start_meta, :__args__)

      assert_receive {:telemetry, [:otel_dec_test, :default, :stop], %{duration: _}, stop_meta}
      refute Map.has_key?(stop_meta, :__result__)
    end
  end

  describe "capture_io: true" do
    test "captures __args__ at start and __result__ at stop, plus code.*" do
      attach_capture([[:otel_dec_test, :captured]])

      assert Captured.hello("ada") == "hello ada"

      assert_receive {:telemetry, [:otel_dec_test, :captured, :start], _, start_meta}
      assert start_meta[:"code.function.name"] == "Otel.TelemetrySpanDecoratorTest.Captured.hello"
      assert start_meta.__args__ == %{name: "ada"}

      assert_receive {:telemetry, [:otel_dec_test, :captured, :stop], _, stop_meta}
      assert stop_meta.__result__ == "hello ada"
    end
  end

  describe "multi-clause def" do
    test "all clauses share the same wrapping; one span per call" do
      attach_capture([[:otel_dec_test, :multi]])

      assert MultiClause.kind(0) == :zero
      assert MultiClause.kind(5) == :positive
      assert MultiClause.kind(-1) == :negative

      for {arg_value, return_value} <- [{0, :zero}, {5, :positive}, {-1, :negative}] do
        assert_receive {:telemetry, [:otel_dec_test, :multi, :start], _, start_meta}
        # Pattern-matching clauses → arg name falls back to
        # `:arg_0` (no source-text name available).
        assert start_meta.__args__ == %{arg_0: arg_value}

        assert_receive {:telemetry, [:otel_dec_test, :multi, :stop], _, stop_meta}
        assert stop_meta.__result__ == return_value
      end
    end
  end

  describe "default args (with capture_io)" do
    test "captures both required and defaulted arg at top level" do
      attach_capture([[:otel_dec_test, :default_arg]])

      assert DefaultArg.greet("world") == "hello world"

      assert_receive {:telemetry, [:otel_dec_test, :default_arg, :start], _, start_meta}
      assert start_meta.__args__ == %{name: "world", greeting: "hello"}
    end
  end

  describe "pattern-match args (with capture_io)" do
    test "falls back to positional `arg_<idx>` name" do
      attach_capture([[:otel_dec_test, :pattern]])

      assert PatternArg.first_name(%{name: "alice"}) == "alice"

      assert_receive {:telemetry, [:otel_dec_test, :pattern, :start], _, start_meta}
      assert start_meta.__args__ == %{arg_0: %{name: "alice"}}
    end
  end

  describe "underscore args (with capture_io)" do
    test "underscore-prefixed args ARE captured (no drop)" do
      attach_capture([[:otel_dec_test, :underscore]])

      assert UnderscoreArg.add(1, :ignored, 2) == 3

      assert_receive {:telemetry, [:otel_dec_test, :underscore, :start], _, start_meta}
      # Leading `_` preserved in metadata key — privacy
      # filtering is the caller's responsibility, not ours.
      assert start_meta.__args__ == %{a: 1, _ignored: :ignored, b: 2}
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

      assert_receive {:telemetry, [:otel_dec_test, :private, :start], _, start_meta}
      assert start_meta.__args__ == %{x: 3}
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
