defmodule Otel.OTLP.HTTP.RetryTest do
  use ExUnit.Case, async: false

  @ok_resp "HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n"
  @retry_opts %{initial_backoff_ms: 1, max_backoff_ms: 5, jitter_ratio: 0.0}

  setup do
    :inets.start()
    :ok
  end

  defp start_test_server(responses) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    counter = :counters.new(1, [])
    pid = spawn_link(fn -> accept_loop(listen, responses, counter) end)
    {pid, port, listen, counter}
  end

  defp accept_loop(listen, responses, counter) do
    case :gen_tcp.accept(listen, 5_000) do
      {:ok, socket} ->
        :counters.add(counter, 1, 1)
        idx = :counters.get(counter, 1)
        response = Enum.at(responses, idx - 1, @ok_resp)
        {:ok, _} = :gen_tcp.recv(socket, 0, 5_000)
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

  defp resp(status), do: "HTTP/1.1 #{status} ERR\r\ncontent-length: 0\r\n\r\n"

  test "200 OK on first attempt — no retry" do
    {pid, port, listen, counter} = start_test_server([@ok_resp])
    assert :ok = post("http://localhost:#{port}")
    assert :counters.get(counter, 1) == 1
    stop_test_server(pid, listen)
  end

  describe "retryable status codes (429, 502, 503, 504)" do
    test "each retryable code retries once and then succeeds on 200" do
      for status <- [429, 502, 503, 504] do
        {pid, port, listen, counter} = start_test_server([resp(status), @ok_resp])

        assert :ok = post("http://localhost:#{port}", @retry_opts)
        assert :counters.get(counter, 1) == 2
        stop_test_server(pid, listen)
      end
    end

    test "persistent failure exhausts max_attempts and returns {:error, _}" do
      {pid, port, listen, counter} = start_test_server(List.duplicate(resp(503), 5))
      opts = Map.put(@retry_opts, :max_attempts, 3)

      assert {:error, {:http_status, 503}} = post("http://localhost:#{port}", opts)
      assert :counters.get(counter, 1) == 3
      stop_test_server(pid, listen)
    end
  end

  describe "non-retryable status codes (400, 401, 403, 404)" do
    test "fail fast on the first response — no retry" do
      for status <- [400, 401, 403, 404] do
        {pid, port, listen, counter} = start_test_server([resp(status)])

        assert {:error, {:http_status, ^status}} = post("http://localhost:#{port}")
        assert :counters.get(counter, 1) == 1
        stop_test_server(pid, listen)
      end
    end
  end

  test "connection errors retry up to max_attempts and then return {:error, _}" do
    # A port nothing is listening on triggers econnrefused.
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    :gen_tcp.close(listen)

    assert {:error, _} = post("http://localhost:#{port}", Map.put(@retry_opts, :max_attempts, 2))
  end

  describe "Retry-After header" do
    test "honoured when present and parseable: shortens the wait below the configured backoff" do
      retry_503_with_after_1s =
        "HTTP/1.1 503 Service Unavailable\r\nretry-after: 1\r\ncontent-length: 0\r\n\r\n"

      {pid, port, listen, counter} = start_test_server([retry_503_with_after_1s, @ok_resp])

      # Configured backoff is 10s; Retry-After is 1s — must elapse ~1s, not ~10s.
      opts = %{initial_backoff_ms: 10_000, max_backoff_ms: 10_000, jitter_ratio: 0.0}
      started = System.monotonic_time(:millisecond)

      assert :ok = post("http://localhost:#{port}", opts)
      elapsed = System.monotonic_time(:millisecond) - started

      assert elapsed >= 900 and elapsed < 5_000
      assert :counters.get(counter, 1) == 2
      stop_test_server(pid, listen)
    end

    test "ignored when unparseable or zero — falls back to configured backoff" do
      for header_value <- ["tomorrow", "0"] do
        bad_after =
          "HTTP/1.1 503 Service Unavailable\r\nretry-after: #{header_value}\r\ncontent-length: 0\r\n\r\n"

        {pid, port, listen, counter} = start_test_server([bad_after, @ok_resp])
        assert :ok = post("http://localhost:#{port}", @retry_opts)
        assert :counters.get(counter, 1) == 2
        stop_test_server(pid, listen)
      end
    end
  end

  test "request/3 (no retry_opts) uses the default policy" do
    {pid, port, listen, counter} = start_test_server([@ok_resp])

    assert :ok =
             Otel.OTLP.HTTP.Retry.request(
               {String.to_charlist("http://localhost:#{port}"), [], ~c"application/x-protobuf",
                "body"},
               [],
               []
             )

    assert :counters.get(counter, 1) == 1
    stop_test_server(pid, listen)
  end
end
