defmodule Otel.Logs.LogRecordStorageTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
    :ok
  end

  @record %Otel.Logs.LogRecord{
    body: "hello",
    severity_number: 9,
    severity_text: "INFO",
    timestamp: 1_000_000,
    observed_timestamp: 2_000_000,
    attributes: %{"key" => "value"}
  }

  describe "insert/1 + take/1" do
    test "insert → take returns the record once; subsequent take is empty" do
      assert :ok = Otel.Logs.LogRecordStorage.insert(@record)

      assert [%Otel.Logs.LogRecord{body: "hello"}] = Otel.Logs.LogRecordStorage.take(10)
      assert [] = Otel.Logs.LogRecordStorage.take(10)
    end

    test "take respects the batch size" do
      for i <- 1..5 do
        Otel.Logs.LogRecordStorage.insert(%{@record | body: "msg-#{i}"})
      end

      first = Otel.Logs.LogRecordStorage.take(3)
      rest = Otel.Logs.LogRecordStorage.take(10)

      assert length(first) == 3
      assert length(rest) == 2
    end
  end

  describe "backpressure" do
    # `insert/1` silently drops once `@max_queue_size` (2_048) is
    # reached. Tests bypass the public API and `:ets.insert/2`
    # directly to fill the table without paying 2_048 individual
    # `insert/1` calls.
    test "insert is a no-op once the table holds @max_queue_size rows" do
      now = System.system_time(:millisecond)

      for k <- 1..2_048 do
        :ets.insert(Otel.Logs.LogRecordStorage, {k, @record, now})
      end

      assert :ets.info(Otel.Logs.LogRecordStorage, :size) == 2_048

      assert :ok = Otel.Logs.LogRecordStorage.insert(@record)
      assert :ets.info(Otel.Logs.LogRecordStorage, :size) == 2_048
    end
  end

  describe "sweep stale records" do
    # Sweep keys off the row's `inserted_at_ms` (3rd column).
    # `insert/1` always stamps it with `System.system_time(:millisecond)`
    # at call time, so to simulate a stale row these tests bypass
    # the public API and `:ets.insert/2` directly with a backdated
    # value.
    @stale_inserted_at System.system_time(:millisecond) - :timer.minutes(31)

    test "removes records whose inserted_at is older than the TTL" do
      :ets.insert(Otel.Logs.LogRecordStorage, {1, @record, @stale_inserted_at})

      send(Otel.Logs.LogRecordStorage, :loop)
      :sys.get_state(Otel.Logs.LogRecordStorage)

      assert [] = Otel.Logs.LogRecordStorage.take(10)
    end

    test "keeps records within the TTL" do
      Otel.Logs.LogRecordStorage.insert(@record)

      send(Otel.Logs.LogRecordStorage, :loop)
      :sys.get_state(Otel.Logs.LogRecordStorage)

      assert [%Otel.Logs.LogRecord{}] = Otel.Logs.LogRecordStorage.take(10)
    end
  end

  test "ETS table is named, public, and write-concurrent" do
    info = :ets.info(Otel.Logs.LogRecordStorage)

    assert info[:named_table] == true
    assert info[:protection] == :public
    assert info[:write_concurrency] != false
  end
end
