defmodule Otel.SDK.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for active spans.

  A GenServer that owns the ETS table. The table is `public` with
  `write_concurrency` and `read_concurrency` so any process can
  read/write spans without going through this server.

  Keys are the 8-byte binary form of `Otel.API.Trace.SpanId` so ETS
  comparison stays O(1) on a fixed-length binary.
  """

  use GenServer

  @table_name :otel_span_table

  # --- Client API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Inserts a span into the table.
  """
  @spec insert(span :: Otel.SDK.Trace.Span.t()) :: true
  def insert(span) do
    :ets.insert(@table_name, {key(span.span_id), span})
  end

  @doc """
  Looks up a span by SpanId.
  """
  @spec get(span_id :: Otel.API.Trace.SpanId.t()) :: Otel.SDK.Trace.Span.t() | nil
  def get(%Otel.API.Trace.SpanId{} = span_id) do
    k = key(span_id)

    case :ets.lookup(@table_name, k) do
      [{^k, span}] -> span
      [] -> nil
    end
  end

  @doc """
  Removes and returns a span by SpanId.
  """
  @spec take(span_id :: Otel.API.Trace.SpanId.t()) :: Otel.SDK.Trace.Span.t() | nil
  def take(%Otel.API.Trace.SpanId{} = span_id) do
    k = key(span_id)

    case :ets.take(@table_name, k) do
      [{^k, span}] -> span
      [] -> nil
    end
  end

  @doc """
  Returns the ETS table name.
  """
  @spec table_name() :: atom()
  def table_name, do: @table_name

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        {:write_concurrency, true},
        {:read_concurrency, true}
      ])

    {:ok, %{table: table}}
  end

  # --- Internal ---

  @spec key(span_id :: Otel.API.Trace.SpanId.t()) :: <<_::64>>
  defp key(%Otel.API.Trace.SpanId{bytes: bytes}), do: bytes
end
