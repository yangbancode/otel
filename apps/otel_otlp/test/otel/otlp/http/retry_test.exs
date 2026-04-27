defmodule Otel.OTLP.HTTP.RetryTest do
  use ExUnit.Case, async: false

  setup do
    :inets.start()
    :ok
  end

  defp start_test_server(responses) when is_list(responses) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    counter = :counters.new(1, [])

    pid =
      spawn_link(fn ->
        accept_loop(listen, responses, counter)
      end)

    {pid, port, listen, counter}
  end

  defp accept_loop(listen, responses, counter) do
    case :gen_tcp.accept(listen, 5_000) do
      {:ok, socket} ->
        :counters.add(counter, 1, 1)
        idx = :counters.get(counter, 1)
        response = Enum.at(responses, idx - 1, "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n")

        {:ok, _data} = :gen_tcp.recv(socket, 0, 5_000)
        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        accept_loop(listen, responses, counter)

      _ ->
        :ok
    end
  end

  defp stop_test_server(pid, listen) do
    :gen_tcp.close(listen)
    ref = Process.monitor(pid)
    receive do: ({:DOWN, ^ref, _, _, _} -> :ok), after: (1_000 -> :ok)
  end

  defp post(url, retry_opts \\ %{}) do
    Otel.OTLP.HTTP.Retry.request(
      {String.to_charlist(url), [], ~c"application/x-protobuf", "body"},
      [],
      [],
      retry_opts
    )
  end

  describe "request/4 success" do
    test "returns :ok on first 200 OK" do
      {pid, port, listen, counter} =
        start_test_server(["HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"])

      assert :ok = post("http://localhost:#{port}")
      assert :counters.get(counter, 1) == 1
      stop_test_server(pid, listen)
    end
  end

  describe "request/4 transient errors" do
    test "retries on 503 then succeeds" do
      {pid, port, listen, counter} =
        start_test_server([
          "HTTP/1.1 503 Service Unavailable\r\ncontent-length: 0\r\n\r\n",
          "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"
        ])

      retry_opts = %{initial_backoff_ms: 1, max_backoff_ms: 5, jitter_ratio: 0.0}
      assert :ok = post("http://localhost:#{port}", retry_opts)
      assert :counters.get(counter, 1) == 2
      stop_test_server(pid, listen)
    end

    test "retries on 502/504/429 (each retryable)" do
      for status <- [429, 502, 503, 504] do
        {pid, port, listen, counter} =
          start_test_server([
            "HTTP/1.1 #{status} ERR\r\ncontent-length: 0\r\n\r\n",
            "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"
          ])

        retry_opts = %{initial_backoff_ms: 1, max_backoff_ms: 5, jitter_ratio: 0.0}
        assert :ok = post("http://localhost:#{port}", retry_opts)
        assert :counters.get(counter, 1) == 2
        stop_test_server(pid, listen)
      end
    end

    test "returns {:error, _} after exhausting attempts on persistent 503" do
      {pid, port, listen, counter} =
        start_test_server(
          List.duplicate("HTTP/1.1 503 Service Unavailable\r\ncontent-length: 0\r\n\r\n", 5)
        )

      retry_opts = %{
        max_attempts: 3,
        initial_backoff_ms: 1,
        max_backoff_ms: 5,
        jitter_ratio: 0.0
      }

      assert {:error, {:http_status, 503}} = post("http://localhost:#{port}", retry_opts)
      assert :counters.get(counter, 1) == 3
      stop_test_server(pid, listen)
    end
  end

  describe "request/4 non-retryable errors" do
    test "returns {:error, _} immediately on 400 Bad Request" do
      {pid, port, listen, counter} =
        start_test_server([
          "HTTP/1.1 400 Bad Request\r\ncontent-length: 0\r\n\r\n",
          "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"
        ])

      assert {:error, {:http_status, 400}} = post("http://localhost:#{port}")
      assert :counters.get(counter, 1) == 1
      stop_test_server(pid, listen)
    end

    test "returns {:error, _} immediately on 401/403/404" do
      for status <- [401, 403, 404] do
        {pid, port, listen, counter} =
          start_test_server([
            "HTTP/1.1 #{status} ERR\r\ncontent-length: 0\r\n\r\n"
          ])

        assert {:error, {:http_status, ^status}} = post("http://localhost:#{port}")
        assert :counters.get(counter, 1) == 1
        stop_test_server(pid, listen)
      end
    end
  end

  describe "request/4 connection errors" do
    test "retries when server is unreachable" do
      # Use a port that nothing is listening on. After max_attempts
      # the request returns {:error, _} (econnrefused or similar).
      {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(listen)
      :gen_tcp.close(listen)

      retry_opts = %{
        max_attempts: 2,
        initial_backoff_ms: 1,
        max_backoff_ms: 5,
        jitter_ratio: 0.0
      }

      assert {:error, _} = post("http://localhost:#{port}", retry_opts)
    end
  end

  describe "request/4 Retry-After header" do
    test "honors Retry-After delta-seconds on 503" do
      {pid, port, listen, counter} =
        start_test_server([
          "HTTP/1.1 503 Service Unavailable\r\nretry-after: 1\r\ncontent-length: 0\r\n\r\n",
          "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"
        ])

      retry_opts = %{initial_backoff_ms: 10_000, max_backoff_ms: 10_000, jitter_ratio: 0.0}
      started = System.monotonic_time(:millisecond)
      assert :ok = post("http://localhost:#{port}", retry_opts)
      elapsed = System.monotonic_time(:millisecond) - started

      # Retry-After was 1s; backoff would have been 10s. We should
      # have waited ~1s, not ~10s.
      assert elapsed < 5_000
      assert elapsed >= 900
      assert :counters.get(counter, 1) == 2
      stop_test_server(pid, listen)
    end

    test "ignores unparseable Retry-After value (falls back to backoff)" do
      {pid, port, listen, counter} =
        start_test_server([
          "HTTP/1.1 503 Service Unavailable\r\nretry-after: tomorrow\r\ncontent-length: 0\r\n\r\n",
          "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"
        ])

      retry_opts = %{initial_backoff_ms: 1, max_backoff_ms: 5, jitter_ratio: 0.0}
      assert :ok = post("http://localhost:#{port}", retry_opts)
      assert :counters.get(counter, 1) == 2
      stop_test_server(pid, listen)
    end
  end
end
