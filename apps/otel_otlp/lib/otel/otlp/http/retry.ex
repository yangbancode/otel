defmodule Otel.OTLP.HTTP.Retry do
  @moduledoc """
  Retry wrapper around `:httpc.request/4` for OTLP/HTTP exporters.

  Spec `protocol/exporter.md` §Retry L181-L183:

  > *"Transient errors MUST be handled with a retry strategy.
  > This retry strategy MUST implement an exponential back-off
  > with jitter to avoid overwhelming the destination until
  > the network is restored or the destination has recovered."*

  Linked from `opentelemetry-proto/docs/specification.md`
  §"OTLP/HTTP Throttling" L590-L600 and §"All Other Responses"
  L605-L611 / §"OTLP/HTTP Connection" L615-L621.

  ## Retryable conditions

  Per `opentelemetry-proto/docs/specification.md` §"Retryable
  Response Codes" L565-L573:

  | Status | Retry? |
  |---|---|
  | 200-299 | success — no retry |
  | 429 Too Many Requests | retry, honor `Retry-After` |
  | 502 Bad Gateway | retry |
  | 503 Service Unavailable | retry, honor `Retry-After` |
  | 504 Gateway Timeout | retry |
  | other 4xx/5xx | non-retryable, fail |
  | connection errors | retry |

  When the server returns a retryable response with a
  `Retry-After` header (RFC 7231 §7.1.3), the retry honors
  the delta-seconds value rather than computing its own
  backoff (spec L590-L596 SHOULD).

  Only the delta-seconds form is parsed. RFC 7231 also
  permits an `HTTP-date` form (`"Fri, 31 Dec 1999 23:59:59
  GMT"`); when the server uses that form, the parser
  returns `nil` and the code falls back to the computed
  exponential backoff for that retry. The spec clause is
  SHOULD, so falling back is conformant; OTLP servers
  emit delta-seconds in practice.

  ## Backoff formula

  - `delay(n) = min(initial * multiplier^n, max_backoff)`
  - jitter: each delay is multiplied by a random factor
    `(1 + jitter_ratio * U(-1, 1))`

  Defaults are chosen to match the Java OTLP SDK's published
  defaults (no spec mandate on values):

  | Option | Default | Description |
  |---|---|---|
  | `:max_attempts` | 5 | total attempts including the first |
  | `:initial_backoff_ms` | 1_000 | first retry delay before jitter |
  | `:max_backoff_ms` | 5_000 | upper bound on per-attempt delay |
  | `:multiplier` | 1.5 | exponential growth factor |
  | `:jitter_ratio` | 0.2 | ±20% randomization on each delay |

  ## Return shape

  `request/5` returns `:ok` if any attempt receives a 2xx
  response. After exhausting retries on transient errors, or
  on the first non-retryable response, it returns
  `{:error, reason}`. The caller (an OTLP exporter) is then
  responsible for satisfying its own behaviour contract
  (`SpanExporter.export/3`, etc.) — exporters typically map
  the `{:error, _}` to `:error` on the SDK behaviour.
  """

  @type retry_opts :: %{
          optional(:max_attempts) => pos_integer(),
          optional(:initial_backoff_ms) => pos_integer(),
          optional(:max_backoff_ms) => pos_integer(),
          optional(:multiplier) => float(),
          optional(:jitter_ratio) => float()
        }

  @type request_args :: {
          url :: charlist(),
          headers :: [{charlist(), charlist()}],
          content_type :: charlist(),
          body :: binary()
        }

  @default_max_attempts 5
  @default_initial_backoff_ms 1_000
  @default_max_backoff_ms 5_000
  @default_multiplier 1.5
  @default_jitter_ratio 0.2

  @retryable_statuses [429, 502, 503, 504]

  @doc """
  Sends an OTLP/HTTP POST with retry on transient errors.

  `request_args` are the positional args to `:httpc.request/4`'s
  request body (`{url, headers, content_type, body}`).
  `http_options` and `request_options` are passed through as
  the third and fourth `:httpc.request/4` arguments.

  Retries are governed by `retry_opts`; defaults are applied
  for any keys not provided.
  """
  @spec request(
          request_args :: request_args(),
          http_options :: keyword(),
          request_options :: keyword(),
          retry_opts :: retry_opts()
        ) :: :ok | {:error, term()}
  def request(request_args, http_options, request_options, retry_opts \\ %{}) do
    opts = merge_defaults(retry_opts)
    do_request(request_args, http_options, request_options, opts, 0)
  end

  @spec do_request(
          request_args :: request_args(),
          http_options :: keyword(),
          request_options :: keyword(),
          opts :: map(),
          attempt :: non_neg_integer()
        ) :: :ok | {:error, term()}
  defp do_request(request_args, http_options, request_options, opts, attempt) do
    case :httpc.request(:post, request_args, http_options, request_options) do
      {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 ->
        :ok

      {:ok, {{_version, status, _reason}, response_headers, _body}}
      when status in @retryable_statuses ->
        if attempt + 1 < opts.max_attempts do
          delay = retry_after_delay(response_headers) || backoff_delay(attempt, opts)
          Process.sleep(delay)
          do_request(request_args, http_options, request_options, opts, attempt + 1)
        else
          {:error, {:http_status, status}}
        end

      {:ok, {{_version, status, _reason}, _headers, _body}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        if attempt + 1 < opts.max_attempts do
          delay = backoff_delay(attempt, opts)
          Process.sleep(delay)
          do_request(request_args, http_options, request_options, opts, attempt + 1)
        else
          {:error, reason}
        end
    end
  end

  @spec merge_defaults(retry_opts :: retry_opts()) :: map()
  defp merge_defaults(opts) do
    %{
      max_attempts: Map.get(opts, :max_attempts, @default_max_attempts),
      initial_backoff_ms: Map.get(opts, :initial_backoff_ms, @default_initial_backoff_ms),
      max_backoff_ms: Map.get(opts, :max_backoff_ms, @default_max_backoff_ms),
      multiplier: Map.get(opts, :multiplier, @default_multiplier),
      jitter_ratio: Map.get(opts, :jitter_ratio, @default_jitter_ratio)
    }
  end

  # Spec `proto/specification.md` L592 SHOULD: honor Retry-After
  # on 429/503. RFC 7231 §7.1.3 permits both delta-seconds (an
  # integer) and HTTP-date forms; in practice OTLP servers use
  # delta-seconds, so we parse only that. An unparseable value
  # falls through to backoff.
  @spec retry_after_delay(headers :: [{charlist(), charlist()}]) :: pos_integer() | nil
  defp retry_after_delay(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if downcased(key) == ~c"retry-after" do
          parse_retry_after(value)
        end
    end)
  end

  @spec downcased(charlist :: charlist()) :: charlist()
  defp downcased(charlist),
    do: charlist |> List.to_string() |> String.downcase() |> String.to_charlist()

  @spec parse_retry_after(value :: charlist()) :: pos_integer() | nil
  defp parse_retry_after(value) do
    case Integer.parse(List.to_string(value)) do
      {seconds, ""} when seconds > 0 -> seconds * 1_000
      _ -> nil
    end
  end

  # Exponential backoff with jitter.
  # `attempt` is 0-indexed (0 = before the first retry).
  @spec backoff_delay(attempt :: non_neg_integer(), opts :: map()) :: pos_integer()
  defp backoff_delay(attempt, opts) do
    base = opts.initial_backoff_ms * :math.pow(opts.multiplier, attempt)
    capped = min(base, opts.max_backoff_ms)
    jitter = capped * opts.jitter_ratio * (:rand.uniform() * 2 - 1)
    delay = capped + jitter

    delay
    |> round()
    |> max(1)
  end
end
