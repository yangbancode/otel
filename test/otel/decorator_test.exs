defmodule Otel.DecoratorTest do
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
    use Otel.Decorator

    @span [:otel_dec_test, :single]
    def hello(name), do: "hello #{name}"
  end

  defmodule MultiClause do
    use Otel.Decorator

    @span [:otel_dec_test, :multi]
    def kind(0), do: :zero
    def kind(n) when n > 0, do: :positive
    def kind(_), do: :negative
  end

  defmodule DefaultArg do
    use Otel.Decorator

    @span [:otel_dec_test, :default]
    def greet(name, greeting \\ "hello"), do: "#{greeting} #{name}"
  end

  defmodule PatternArg do
    use Otel.Decorator

    @span [:otel_dec_test, :pattern]
    def first_name(%{name: name}), do: name
  end

  defmodule UnderscoreArg do
    use Otel.Decorator

    @span [:otel_dec_test, :underscore]
    def add(a, _ignored, b), do: a + b
  end

  defmodule WithGuard do
    use Otel.Decorator

    @span [:otel_dec_test, :guard]
    def positive?(n) when is_integer(n) and n > 0, do: true
    def positive?(_), do: false
  end

  defmodule PrivateFn do
    use Otel.Decorator

    def public_call(x), do: private_helper(x)

    @span [:otel_dec_test, :private]
    defp private_helper(x), do: x * 2
  end

  defmodule NoSpan do
    use Otel.Decorator

    def plain(x), do: x + 1
  end

  defmodule RaisingFn do
    use Otel.Decorator

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
    test "wraps body in :telemetry.span/3 + auto-captures arg by name" do
      attach_capture([[:otel_dec_test, :single]])

      assert SingleClause.hello("world") == "hello world"

      assert_receive {:telemetry, [:otel_dec_test, :single, :start], _measure,
                      %{name: "world"} = start_meta}

      # Plain string-keyed metadata, plus telemetry's own
      # context ref (`telemetry_span_context`).
      assert Map.get(start_meta, :name) == "world" or Map.get(start_meta, "name") == "world"

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
    test "captures both required and defaulted arg by name" do
      attach_capture([[:otel_dec_test, :default]])

      assert DefaultArg.greet("world") == "hello world"

      assert_receive {:telemetry, [:otel_dec_test, :default, :start], _, meta}
      assert meta_value(meta, :name) == "world"
      assert meta_value(meta, :greeting) == "hello"
    end
  end

  describe "pattern-match args" do
    test "falls back to positional `arg_<idx>` name" do
      attach_capture([[:otel_dec_test, :pattern]])

      assert PatternArg.first_name(%{name: "alice"}) == "alice"

      assert_receive {:telemetry, [:otel_dec_test, :pattern, :start], _, meta}
      # Pattern arg → no source name, captured as arg_0
      assert meta_value(meta, :arg_0) == %{name: "alice"}
    end
  end

  describe "underscore args" do
    test "underscore-prefixed args are not captured into metadata" do
      attach_capture([[:otel_dec_test, :underscore]])

      assert UnderscoreArg.add(1, :ignored, 2) == 3

      assert_receive {:telemetry, [:otel_dec_test, :underscore, :start], _, meta}
      assert meta_value(meta, :a) == 1
      assert meta_value(meta, :b) == 2
      refute Map.has_key?(meta, "_ignored")
      refute Map.has_key?(meta, :_ignored)
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
      assert meta_value(meta, :x) == 3
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

  defp meta_value(meta, key) when is_atom(key) do
    Map.get(meta, key) || Map.get(meta, Atom.to_string(key))
  end
end
